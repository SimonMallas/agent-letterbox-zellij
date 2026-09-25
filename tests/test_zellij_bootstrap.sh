#!/usr/bin/env bash
# Isolated live Zellij proof: disposable named session only (PTY-held).
# Never attaches to the caller's default interactive session as a target.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
letterbox="$root/bin/letterbox"
adapter="$root/adapters/zellij.sh"

command -v zellij >/dev/null 2>&1 || {
  echo 'zellij bootstrap test: SKIP (zellij unavailable)'
  exit 0
}
command -v python3 >/dev/null 2>&1 || {
  echo 'zellij bootstrap test: FAIL (python3 required for PTY harness)'
  exit 1
}

tmp="/tmp/lbz$$"
rm -rf "$tmp"
mkdir -p "$tmp/ipc"
# Zellij unix sockets sit under TMPDIR. Darwin sun_path is 104 bytes
# including NUL; a long inherited TMPDIR leaves 0 bytes for the session name.
export TMPDIR="$tmp/ipc"
sess=""
zellij_pid=""
export PATH="$root/bin:$PATH"

# Every direct zellij call is time-bounded: a blocked client must fail the test
# with a named diagnostic, never hang the job. Mirrors the adapter's bounded_cmd.
zb() { # $1=seconds, rest=zellij argv; 124 = timed out
  python3 -c '
import os, signal, subprocess, sys
p = subprocess.Popen(["zellij"] + sys.argv[2:], start_new_session=True)
try:
    sys.exit(p.wait(timeout=float(sys.argv[1])))
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    p.wait()
    sys.stderr.write("zellij call timed out after %ss: zellij %s\n" % (sys.argv[1], " ".join(sys.argv[2:])))
    sys.exit(124)
' "$@"
}

# Remove every process of one disposable session (holder, client, server)
# and prove none is left, so a failed attempt cannot leak into the next.
reap_session() { # $1 = session name
  local name="$1" i
  zb 10 delete-session --force "$name" >/dev/null 2>&1 || true
  if [[ -n "${zellij_pid:-}" ]]; then
    kill "$zellij_pid" >/dev/null 2>&1 || true
    wait "$zellij_pid" 2>/dev/null || true
    zellij_pid=""
  fi
  pkill -f -- "$name" >/dev/null 2>&1 || true
  for i in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f -- "$name" >/dev/null 2>&1 || return 0
    sleep 0.5
  done
  pkill -9 -f -- "$name" >/dev/null 2>&1 || true
  sleep 0.5
  if pgrep -f -- "$name" >/dev/null 2>&1; then
    echo "zellij cleanup: processes for $name still present:" >&2
    ps -A -o pid=,command= | awk -v s="$name" 'index($0, s) && !index($0, "awk -v s")' >&2 || true
  fi
}

cleanup() {
  set +e
  local n
  for n in 1 2 3; do
    reap_session "lbz$$a$n"
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

# Start the disposable session. On GitHub's macOS runners the Zellij server
# itself occasionally dies during start-up (client: "Received empty unknown
# from server"), before any Letterbox code runs. Only this harness set-up is
# retried, at most 3 attempts, each with a fresh session and full diagnostics;
# every Letterbox assertion below runs exactly once.
start_session() { # $1 = attempt number; 0 = session ready with terminal_0
  local n="$1" d="$tmp/attempt$1" t0=$SECONDS ready=0 panes
  mkdir -p "$d"
  sess="lbz$$a$n"
  # The holder keeps a real PTY open and records zellij's output and exit status.
  python3 - "$sess" "$d/pty.log" "$d/exit" <<'PY' &
import os, pty, sys
sess, log_path, exit_path = sys.argv[1], sys.argv[2], sys.argv[3]
env = os.environ.copy()
env["TERM"] = "xterm-256color"
pid, fd = pty.fork()
if pid == 0:
    os.chdir("/tmp")
    os.write(1, b"[holder] exec zellij --debug -s " + sess.encode() + b"\r\n")
    os.execvpe("zellij", ["zellij", "--debug", "-s", sess], env)
with open(log_path, "ab", buffering=0) as log:
    try:
        while True:
            try:
                data = os.read(fd, 4096)
            except OSError:
                break
            if not data:
                break
            log.write(data)
    except KeyboardInterrupt:
        pass
_, status = os.waitpid(pid, 0)
with open(exit_path, "w") as f:
    f.write("exit=%s signal=%s\n" % (
        os.WEXITSTATUS(status) if os.WIFEXITED(status) else "-",
        os.WTERMSIG(status) if os.WIFSIGNALED(status) else "-"))
PY
  zellij_pid=$!
  # Wait for the first terminal pane, not just a responding server.
  while (( SECONDS < t0 + 60 )); do
    panes="$(zb 5 -s "$sess" action list-panes 2>/dev/null || true)"
    if printf '%s\n' "$panes" | grep -q 'terminal_0'; then
      ready=1
      break
    fi
    [[ -s "$d/exit" ]] && break  # client already gone: stop waiting
    sleep 0.1
  done
  (( ready == 1 )) && return 0
  {
    echo "zellij session start attempt $n failed after $((SECONDS - t0))s (no terminal_0)"
    zb 5 list-sessions || true
    if [[ -s "$d/exit" ]]; then
      echo "zellij client exited: $(cat "$d/exit")"
    else
      echo 'zellij client still running (no exit recorded)'
    fi
    echo "holder process tree:"
    ps -A -o pid=,ppid=,stat=,etime=,command= 2>/dev/null \
      | awk -v s="$sess" -v p="$zellij_pid" '(index($0, s) || $1 == p || $2 == p) && !index($0, "awk -v s")' || true
    echo "zellij PTY output: $(wc -c < "$d/pty.log" 2>/dev/null | tr -d ' ') bytes; last 4000, escapes stripped:"
    tail -c 4000 "$d/pty.log" 2>/dev/null \
      | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\e[\]P^_].*?(\a|\e\\)//g; s/\e.//g; s/\r/\n/g' \
      | grep -v '^[[:space:]]*$' | tail -40 || true
    echo "zellij debug log (tail):"
    find "$TMPDIR" -path '*zellij-log*' -type f -name '*.log' 2>/dev/null | while read -r f; do
      echo "--- $f"; tail -c 3000 "$f"; echo
    done
  } >&2
  reap_session "$sess"
  return 1
}

attempts=0
until start_session "$((attempts + 1))"; do
  attempts=$((attempts + 1))
  if (( attempts >= 3 )); then
    echo 'zellij bootstrap test: FAIL (disposable Zellij session did not start in 3 attempts)' >&2
    exit 1
  fi
done
attempts=$((attempts + 1))

# Default first terminal pane in a fresh session is terminal_0 / pane id 0.
pane_list="$(zb 10 -s "$sess" action list-panes)"
printf '%s\n' "$pane_list" | grep -q 'terminal_0' || {
  echo "unexpected panes: $pane_list" >&2
  exit 1
}
printf '%s\n' "isolated session ready: sess=$sess pane=terminal_0 attempts=$attempts"

box="$tmp/box"

# --- setup (isolated HOME for launcher/skill links) ---
HOME="$tmp/home" \
LETTERBOX_BIN_DIR="$tmp/bin" \
LETTERBOX_SKILLS_DIR="$tmp/skills" \
"$letterbox" zellij setup --agents alpha,beta --dir "$box" --automatic-doorbells >/dev/null

test -f "$box/env.sh"
test -f "$box/zellij-agents.tsv"
grep -q 'adapters/zellij.sh' "$box/env.sh"
grep -q 'LETTERBOX_ZELLIJ_SUBMIT=1' "$box/env.sh"
grep -q 'LETTERBOX_ZELLIJ_REGISTRY=' "$box/env.sh"
if grep -qiE 'tmux|cmux|herdr' "$box/env.sh"; then
  echo 'setup env mentions foreign multiplexer' >&2
  exit 1
fi
printf '%s\n' 'zellij setup: PASS'

# --- live register via letterbox zellij run inside the disposable pane ---
: > "$box/zellij-patterns.tsv"
# Zellij injects ZELLIJ_PANE_ID / ZELLIJ_SESSION_NAME into pane shells.
run_cmd="export PATH='$root/bin:'\"\$PATH\" LETTERBOX_DIR='$box' LETTERBOX_ZELLIJ_REGISTRY='$box/zellij-agents.tsv'; letterbox zellij run alpha -- sleep 3600"
zb 10 -s "$sess" action write-chars --pane-id terminal_0 "$run_cmd"
zb 10 -s "$sess" action write --pane-id terminal_0 13

registered=0
for _ in $(seq 1 60); do
  if grep -q $'^alpha\t' "$box/zellij-agents.tsv" 2>/dev/null; then
    registered=1
    break
  fi
  sleep 0.15
done
if [[ "$registered" != 1 ]]; then
  echo 'letterbox zellij run did not register alpha' >&2
  cat "$box/zellij-agents.tsv" >&2 || true
  dump="$tmp/fail-reg.txt"
  zb 10 -s "$sess" action dump-screen --pane-id terminal_0 --path "$dump" 2>/dev/null || true
  cat "$dump" >&2 || true
  exit 1
fi
printf '%s\n' 'zellij run live register: PASS'

reg_line="$(awk -F '\t' '$1=="alpha"{print; exit}' "$box/zellij-agents.tsv")"
printf '%s\n' "$reg_line" | awk -F '\t' -v s="$sess" '
  NF>=3 && $2 != "" && $3 == s { exit 0 }
  { exit 1 }
' || { echo "bad registry line: $reg_line (expected session $sess)" >&2; exit 1; }
printf '%s\n' 'registry pane+session: PASS'

out="$(LETTERBOX_DIR="$box" LETTERBOX_ZELLIJ_REGISTRY="$box/zellij-agents.tsv" "$letterbox" zellij status)"
printf '%s\n' "$out" | grep -q 'alpha' || { echo "status missing alpha: $out" >&2; exit 1; }
printf '%s\n' 'zellij status: PASS'

reg_pane="$(awk -F '\t' '$1=="alpha"{print $2; exit}' "$box/zellij-agents.tsv")"
reg_sess="$(awk -F '\t' '$1=="alpha"{print $3; exit}' "$box/zellij-agents.tsv")"
[[ "$reg_sess" == "$sess" ]] || {
  echo "registered session $reg_sess != disposable session $sess" >&2
  exit 1
}

# --- registry-first doorbell (patterns empty) ---
LETTERBOX_DIR="$box" \
LETTERBOX_ZELLIJ_REGISTRY="$box/zellij-agents.tsv" \
LETTERBOX_ZELLIJ_PATTERNS="$box/zellij-patterns.tsv" \
LETTERBOX_ZELLIJ_SUBMIT=1 \
"$adapter" alpha delegate boot-test

sleep 0.5
dump="$tmp/door-dump.txt"
zb 10 -s "$sess" action dump-screen --pane-id terminal_0 --path "$dump"
if ! grep -Fq "unacked delegate in $box/alpha/inbox/" "$dump"; then
  echo "doorbell not found in dump-screen:" >&2
  cat "$dump" >&2
  exit 1
fi
printf '%s\n' 'registry-first live doorbell: PASS'

LETTERBOX_DIR="$box" LETTERBOX_ZELLIJ_REGISTRY="$box/zellij-agents.tsv" \
  "$letterbox" zellij unregister alpha >/dev/null
if grep -q $'^alpha\t' "$box/zellij-agents.tsv" 2>/dev/null; then
  echo 'unregister failed' >&2
  exit 1
fi
printf '%s\n' 'zellij unregister: PASS'

if "$letterbox" tmux status 2>/dev/null; then
  echo 'tmux subcommand still present' >&2
  exit 1
fi
if "$letterbox" herdr status 2>/dev/null; then
  echo 'herdr subcommand still present' >&2
  exit 1
fi

# Smoke that register works from env (HERDR-equivalent env vars)
: > "$box/zellij-agents.tsv"
ZELLIJ=1 ZELLIJ_PANE_ID="$reg_pane" ZELLIJ_SESSION_NAME="$sess" \
  LETTERBOX_DIR="$box" LETTERBOX_ZELLIJ_REGISTRY="$box/zellij-agents.tsv" \
  "$letterbox" zellij register beta >/dev/null
grep -q $'^beta\t' "$box/zellij-agents.tsv" || {
  echo 'env-based register failed' >&2
  cat "$box/zellij-agents.tsv" >&2
  exit 1
}
printf '%s\n' 'env register (ZELLIJ_PANE_ID + session): PASS'

printf '%s\n' 'zellij bootstrap test: PASS'
