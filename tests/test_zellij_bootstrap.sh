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
mkdir -p "$tmp"
sess="lbz$$"
zellij_pid=""
export PATH="$root/bin:$PATH"

cleanup() {
  set +e
  if [[ -n "${sess:-}" ]]; then
    zellij delete-session --force "$sess" >/dev/null 2>&1
  fi
  if [[ -n "${zellij_pid:-}" ]]; then
    kill "$zellij_pid" >/dev/null 2>&1
    wait "$zellij_pid" 2>/dev/null
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# Hold a real PTY so the disposable session stays active.
python3 - "$sess" <<'PY' &
import os, pty, sys
sess = sys.argv[1]
env = os.environ.copy()
env["TERM"] = "xterm-256color"
pid, fd = pty.fork()
if pid == 0:
    os.chdir("/tmp")
    os.execvpe("zellij", ["zellij", "-s", sess], env)
try:
    while True:
        try:
            os.read(fd, 1024)
        except OSError:
            break
except KeyboardInterrupt:
    pass
os.waitpid(pid, 0)
PY
zellij_pid=$!

ready=0
for _ in $(seq 1 80); do
  if zellij -s "$sess" action list-panes >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.1
done
if [[ "$ready" != 1 ]]; then
  echo 'zellij bootstrap test: FAIL (could not start disposable Zellij session)' >&2
  zellij list-sessions >&2 || true
  exit 1
fi

# Default first terminal pane in a fresh session is terminal_0 / pane id 0.
pane_list="$(zellij -s "$sess" action list-panes)"
printf '%s\n' "$pane_list" | grep -q 'terminal_0' || {
  echo "unexpected panes: $pane_list" >&2
  exit 1
}
printf '%s\n' "isolated session ready: sess=$sess pane=terminal_0"

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
zellij -s "$sess" action write-chars --pane-id terminal_0 "$run_cmd"
zellij -s "$sess" action write --pane-id terminal_0 13

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
  zellij -s "$sess" action dump-screen --pane-id terminal_0 --path "$dump" 2>/dev/null || true
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
zellij -s "$sess" action dump-screen --pane-id terminal_0 --path "$dump"
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
