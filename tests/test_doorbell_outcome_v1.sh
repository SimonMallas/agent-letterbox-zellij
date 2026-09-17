#!/usr/bin/env bash
# Release 2 W2 — zellij edition end-to-end: bin/letterbox send --now with a
# fake zellij and the real adapter, legacy argv forms, plus wrapper classifier
# edge cases. Everything faked inside this temp dir; no real zellij.
set -euo pipefail

EDITION="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ROOT="$(mktemp -d /tmp/r2zellij-test.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT

mkdir -p "$ROOT/bin" "$ROOT/box/agent/inbox" "$ROOT/box/agent/processed" \
         "$ROOT/box/tester/inbox" "$ROOT/box/tester/processed"

printf 'agent\t7\tzession\t2026-09-16T00:00:00Z\n' > "$ROOT/registry.tsv"
printf 'agent\t8\tzession2\n' > "$ROOT/patterns.tsv"

export BOX="$ROOT/box" LETTERBOX_DIR="$ROOT/box" LETTERBOX_AGENT=tester
export LETTERBOX_DOORBELL_TIMEOUT=3

# Fake zellij (behavior by env) ------------------------------------------------
cat > "$ROOT/bin/zellij" <<'ZELLIJ'
#!/usr/bin/env bash
set -uo pipefail
log="${ZELLIJ_FAKE_LOG:?}"
printf '%s\n' "$*" >> "$log"
if [[ "${1:-}" == "-s" ]]; then shift 2; fi
if [[ "${1:-}" == "action" ]]; then
  case "${2:-}" in
    list-panes)
      case "${ZELLIJ_FAKE_LIST:-ok}" in
        ok)    printf 'terminal_7 plugin=false\n';;
        ok8)   printf 'terminal_8 plugin=false\n';;
        empty) :;;
        sleep) sleep "${ZELLIJ_FAKE_SLEEP:-5}";;
        exit124) exit 124;;
      esac
      exit 0;;
    write-chars)
      case "${ZELLIJ_FAKE_SEND:-ok}" in
        ok) exit 0;; fail) exit 1;; sleep) sleep "${ZELLIJ_FAKE_SLEEP:-5}";; exit124) exit 124;;
      esac
      exit 0;;
    write)
      case "${ZELLIJ_FAKE_ENTER:-ok}" in
        ok) exit 0;; fail) exit 1;; sleep) sleep "${ZELLIJ_FAKE_SLEEP:-5}";;
      esac
      exit 0;;
  esac
fi
exit 0
ZELLIJ
chmod +x "$ROOT/bin/zellij"
export PATH="$ROOT/bin:$PATH"
export ZELLIJ_FAKE_LOG="$ROOT/zellij.log"
export LETTERBOX_DOORBELL="$EDITION/adapters/zellij.sh"
export LETTERBOX_ZELLIJ_SUBMIT=1

# Misbehaving doorbells for wrapper classifier edge cases.
cat > "$ROOT/sleeper.sh" <<'SH'
#!/usr/bin/env bash
sleep 30
SH
cat > "$ROOT/garbage.sh" <<'SH'
#!/usr/bin/env bash
echo 'not a contract line'
SH
cat > "$ROOT/double.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7'
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7'
SH
cat > "$ROOT/valid-exit1.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7'
exit 1
SH
cat > "$ROOT/line-hang.sh" <<'SH'
#!/usr/bin/env bash
echo 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7'
sleep 30
SH
chmod +x "$ROOT/sleeper.sh" "$ROOT/garbage.sh" "$ROOT/double.sh" "$ROOT/valid-exit1.sh" "$ROOT/line-hang.sh"

# PATH farm WITH the fake zellij but WITHOUT python3: a missing runner must be
# adapter_unavailable (non-retryable), never helper_timeout.
mkdir -p "$ROOT/bin-nopython"
for t in bash grep awk sed shasum od tr date mktemp ln rm cat \
         dirname basename env sleep; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$src" ]] && ln -sf "$src" "$ROOT/bin-nopython/$t"
done
ln -sf "$ROOT/bin/zellij" "$ROOT/bin-nopython/zellij"

send_now() { # $1.. = env overrides (must trail base assignments to win)
  env BOX="$BOX" LETTERBOX_AGENT=tester LETTERBOX_DIR="$BOX" \
    LETTERBOX_DOORBELL="$LETTERBOX_DOORBELL" LETTERBOX_ZELLIJ_SUBMIT="$LETTERBOX_ZELLIJ_SUBMIT" \
    LETTERBOX_DOORBELL_TIMEOUT="$LETTERBOX_DOORBELL_TIMEOUT" \
    LETTERBOX_ZELLIJ_REGISTRY="$ROOT/registry.tsv" LETTERBOX_ZELLIJ_PATTERNS= \
    PATH="$PATH" ZELLIJ_FAKE_LOG="$ZELLIJ_FAKE_LOG" "$@" \
    bash -c 'printf "test body\n" | "$0" send agent info testslug --now' "$EDITION/bin/letterbox" 2>/dev/null
}

one_line() {
  local out="$1" n
  n="$(printf '%s\n' "$out" | grep -c '^doorbell-outcome ' || true)"
  [[ "$n" == "1" ]] || { echo "SOLE-EMISSION FAIL ($n lines): $out"; exit 1; }
}

craft_letter() { # $1=from $2=id — hand-write a durable letter into agent's inbox
  cat > "$BOX/agent/inbox/$2.md" <<EOF
---
id: $2
from: $1
to: agent
type: info
re:
priority: later
requires_ack: false
deadline:
---
crafted body
EOF
}

nudge() { # $1=id — re-ring an existing letter through the full wrapper path
  env BOX="$BOX" LETTERBOX_AGENT=tester LETTERBOX_DIR="$BOX" \
    LETTERBOX_DOORBELL="$LETTERBOX_DOORBELL" LETTERBOX_ZELLIJ_SUBMIT=1 \
    LETTERBOX_DOORBELL_TIMEOUT="$LETTERBOX_DOORBELL_TIMEOUT" \
    LETTERBOX_ZELLIJ_REGISTRY="$ROOT/registry.tsv" LETTERBOX_ZELLIJ_PATTERNS= \
    PATH="$PATH" ZELLIJ_FAKE_LOG="$ZELLIJ_FAKE_LOG" \
    "$EDITION/bin/letterbox" nudge "$1" 2>/dev/null
}

pass=0
check() { # $1=name $2=env-string $3=expected
  local name="$1" envs="$2" expected="$3" out
  out="$(send_now $envs)"
  one_line "$out"
  out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
  if [[ "$out" == "$expected" ]]; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name"; echo "  expected: $expected"; echo "  got:      $out"; exit 1
  fi
}

check "submitted via registry pane"      "" \
  'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7'
# The injected line carries the v0.3 opaque token derived from the letter id,
# and names the durable letter's sender (from tester).
if grep -Eq "write-chars --pane-id terminal_7 📬 letterbox ""doorbell: unacked info from tester in .*/agent/inbox/ — please check · [0-9a-f]{8}" "$ZELLIJ_FAKE_LOG"; then
  echo "PASS: injected line carries sender + v0.3 token"; pass=$((pass+1))
else
  echo "FAIL: injected line carries sender + v0.3 token"; cat "$ZELLIJ_FAKE_LOG"; exit 1
fi
check "list-panes timeout → helper_timeout" "ZELLIJ_FAKE_LIST=sleep ZELLIJ_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=helper_timeout target=-'
check "pane absent → surface_not_found"  "ZELLIJ_FAKE_LIST=empty" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "patterns fallback → submitted"    "LETTERBOX_ZELLIJ_REGISTRY=$ROOT/missing.tsv LETTERBOX_ZELLIJ_PATTERNS=$ROOT/patterns.tsv ZELLIJ_FAKE_LIST=ok8" \
  'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_8'
check "write-chars reported fail → send_failed" "ZELLIJ_FAKE_SEND=fail" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=send_failed target=-'
check "write-chars timeout → unconfirmed" "ZELLIJ_FAKE_SEND=sleep ZELLIJ_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "enter reported fail → pasted"     "ZELLIJ_FAKE_ENTER=fail" \
  'doorbell-outcome v=1 outcome=pasted_not_submitted reason=enter_failed target=terminal_7'
check "enter timeout → unconfirmed"      "ZELLIJ_FAKE_ENTER=sleep ZELLIJ_FAKE_SLEEP=5" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "notify-only (SUBMIT=0)"           "LETTERBOX_ZELLIJ_SUBMIT=0" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=notify_only target=-'
check "adapter: zellij missing"          "ZELLIJ_BIN_PATH=/nonexistent/zellij" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "missing python3 → adapter_unavailable (not helper_timeout)" "PATH=$ROOT/bin-nopython" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'

# Fail closed without a bounder: prompt adapter_unavailable, and the adapter
# is NEVER invoked (invocation marker must not appear).
cat > "$ROOT/hang-marker.sh" <<'SH'
#!/usr/bin/env bash
touch "${INVOKED_MARKER:?}"
sleep 30
SH
chmod +x "$ROOT/hang-marker.sh"
rm -f "$ROOT/invoked"
out="$(send_now PATH="$ROOT/bin-nopython" LETTERBOX_DOORBELL="$ROOT/hang-marker.sh" INVOKED_MARKER="$ROOT/invoked")"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-' ]] \
  && [[ ! -e "$ROOT/invoked" ]]; then
  echo "PASS: no python3 → adapter_unavailable, adapter never invoked"; pass=$((pass+1))
else
  echo "FAIL: fail-closed without bounder"; echo "$out"; ls -la "$ROOT/invoked" 2>/dev/null; exit 1
fi
check "wrapper: doorbell env unset"      "LETTERBOX_DOORBELL=" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "wrapper: doorbell not executable" "LETTERBOX_DOORBELL=/etc/hosts" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=adapter_unavailable target=-'
check "wrapper: backstop kill → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/sleeper.sh LETTERBOX_DOORBELL_TIMEOUT=1" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "wrapper: garbage child → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/garbage.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
check "wrapper: double line → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/double.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
# Exit-status precedence: a valid line after a NONZERO exit is never forwarded.
check "wrapper: valid line + nonzero exit → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/valid-exit1.sh" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'
# Runner-owned sentinel: a child exiting 124 on its own is NOT a timeout.
check "child exit 124 in lookup → surface_not_found (not helper_timeout)" "ZELLIJ_FAKE_LIST=exit124" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=surface_not_found target=-'
check "child exit 124 in send → send_failed (not unconfirmed)" "ZELLIJ_FAKE_SEND=exit124" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=send_failed target=-'
# A success line followed by a hang: the wrapper backstop kills, line or not.
check "wrapper: valid line then hang → unconfirmed" "LETTERBOX_DOORBELL=$ROOT/line-hang.sh LETTERBOX_DOORBELL_TIMEOUT=1" \
  'doorbell-outcome v=1 outcome=no_live_surface reason=unconfirmed target=-'

# Ruling 5 provenance: the from clause names the durable letter's sender,
# never the calling process identity (ME=tester, letter from relaybot).
craft_letter relaybot 2026-09-16T000000-relaybot-info-crafted-a1b2c3d4
out="$(nudge 2026-09-16T000000-relaybot-info-crafted-a1b2c3d4)"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7' ]] \
  && grep -q 'unacked info from relaybot in ' "$ZELLIJ_FAKE_LOG"; then
  echo "PASS: from clause names the letter's sender, not ME"; pass=$((pass+1))
else
  echo "FAIL: from clause names the letter's sender, not ME"; echo "$out"; cat "$ZELLIJ_FAKE_LOG"; exit 1
fi

# Ruling 5 safety: an invalid sender value omits the clause (never "from -").
craft_letter 'bad/../x' 2026-09-16T000001-badsend-info-crafted-b2c3d4e5
: > "$ZELLIJ_FAKE_LOG"
out="$(nudge 2026-09-16T000001-badsend-info-crafted-b2c3d4e5)"
one_line "$out"
out="$(printf '%s\n' "$out" | grep '^doorbell-outcome ')"
if [[ "$out" == 'doorbell-outcome v=1 outcome=submitted reason=- target=terminal_7' ]] \
  && ! grep -q ' from ' "$ZELLIJ_FAKE_LOG" \
  && grep -q 'unacked info in ' "$ZELLIJ_FAKE_LOG"; then
  echo "PASS: invalid sender omits the from clause"; pass=$((pass+1))
else
  echo "FAIL: invalid sender omits the from clause"; echo "$out"; cat "$ZELLIJ_FAKE_LOG"; exit 1
fi

# Legacy argv forms, exercised directly against the adapter (not the wrapper).
: > "$ZELLIJ_FAKE_LOG"
legacy_out="$(env LETTERBOX_DIR="$BOX" PATH="$PATH" ZELLIJ_FAKE_LOG="$ZELLIJ_FAKE_LOG" \
  LETTERBOX_ZELLIJ_REGISTRY="$ROOT/registry.tsv" LETTERBOX_ZELLIJ_SUBMIT=1 \
  LETTERBOX_DOORBELL_TIMEOUT=2 \
  bash "$EDITION/adapters/zellij.sh" agent info 2026-09-16T010203-kimi-info-testslug-a1b2c3d4)"
one_line "$legacy_out"
if [[ "$legacy_out" == *"outcome=submitted reason=- target=terminal_7" ]] \
  && grep -q '· a1b2c3d4' "$ZELLIJ_FAKE_LOG"; then
  echo "PASS: legacy 3-arg id derives token"; pass=$((pass+1))
else
  echo "FAIL: legacy 3-arg id derives token"; echo "$legacy_out"; cat "$ZELLIJ_FAKE_LOG"; exit 1
fi
: > "$ZELLIJ_FAKE_LOG"
legacy_out="$(env LETTERBOX_DIR="$BOX" PATH="$PATH" ZELLIJ_FAKE_LOG="$ZELLIJ_FAKE_LOG" \
  LETTERBOX_ZELLIJ_REGISTRY="$ROOT/registry.tsv" LETTERBOX_ZELLIJ_SUBMIT=1 \
  LETTERBOX_DOORBELL_TIMEOUT=2 \
  bash "$EDITION/adapters/zellij.sh" agent info testslug)"
one_line "$legacy_out"
if [[ "$legacy_out" == *"outcome=submitted reason=- target=terminal_7" ]] \
  && ! grep -q '· ' "$ZELLIJ_FAKE_LOG"; then
  echo "PASS: legacy slug-only stays v0.2 (no token)"; pass=$((pass+1))
else
  echo "FAIL: legacy slug-only stays v0.2 (no token)"; echo "$legacy_out"; cat "$ZELLIJ_FAKE_LOG"; exit 1
fi

echo "──"
echo "zellij edition e2e: $pass/26 PASS"
