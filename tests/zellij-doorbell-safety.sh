#!/usr/bin/env bash
# Mock-backed proof that adapters/zellij.sh never injects input into a live pane
# unless the caller explicitly opts in via LETTERBOX_ZELLIJ_SUBMIT=1.
#
# Runs anywhere: Zellij itself is never required. The adapter resolves its binary
# through ZELLIJ_BIN_PATH, so we point that at a mock that logs every call.
#
# The mock answers `action list-panes` with real Zellij-shaped output so it
# exercises the adapter's actual pane_token()/awk matcher — a mock that merely
# exits 0 would make the adapter defer at pane lookup, and the refusal
# assertions below would then pass for a reason unrelated to the submit gate.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
adapter="$root/adapters/zellij.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

PANE_NUM=7            # numeric id -> adapter must translate to terminal_7
mock="$work/zellij-mock"
cat > "$mock" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_LOG"
# Strip a leading `-s <session>` so the sub-command is positional.
if [[ "${1:-}" == "-s" ]]; then shift 2; fi
if [[ "${1:-}" == "action" && "${2:-}" == "list-panes" ]]; then
  # Zellij-shaped: first field is the pane token the adapter builds.
  printf 'terminal_%s [Pane #%s] running\n' "$MOCK_PANE" "$MOCK_PANE"
  printf 'terminal_99 [Pane #99] running\n'
fi
exit 0
MOCK
chmod +x "$mock"

box="$work/box"; mkdir -p "$box/reviewer/inbox"
patterns="$box/zellij-patterns.tsv"
printf 'reviewer\t%s\tsess\n' "$PANE_NUM" > "$patterns"

MOCK_LOG="$work/zellij-calls.log"
export MOCK_LOG MOCK_PANE="$PANE_NUM"

run_adapter() {
  : > "$MOCK_LOG"
  ZELLIJ_BIN_PATH="$mock" \
    LETTERBOX_DIR="$box" \
    LETTERBOX_ZELLIJ_PATTERNS="$patterns" \
    MOCK_LOG="$MOCK_LOG" MOCK_PANE="$PANE_NUM" \
    "$adapter" reviewer delegate smoke-test >/dev/null 2>"$work/stderr"
}

injected() { grep -qE 'action (write-chars|write) ' "$MOCK_LOG"; }
fails=0
fail() { printf 'FAIL: %s\n' "$*" >&2; cat "$MOCK_LOG" >&2; fails=$((fails+1)); }

# --- Default (unset): must never inject ---
unset LETTERBOX_ZELLIJ_SUBMIT || true
run_adapter
injected && fail 'zellij action write-chars/write called without LETTERBOX_ZELLIJ_SUBMIT=1'
grep -q 'action list-panes' "$MOCK_LOG" || fail 'adapter never queried list-panes — mock not reached'
(( fails == 0 )) && printf 'PASS: no input injection without opt-in\n'

# --- Explicit 0: same ---
before=$fails
LETTERBOX_ZELLIJ_SUBMIT=0 run_adapter
injected && fail 'zellij injected with LETTERBOX_ZELLIJ_SUBMIT=0'
(( fails == before )) && printf 'PASS: explicit 0 also refuses\n'

# --- Opt-in: MUST inject, and MUST prove the mock pane was actually found. ---
# Without this the two checks above could both pass because the adapter deferred
# at pane lookup and never reached the gate at all.
before=$fails
LETTERBOX_ZELLIJ_SUBMIT=1 run_adapter
grep -q "deferred" "$work/stderr" && fail 'adapter deferred — the mock pane was NOT found, so the refusal checks above prove nothing'
grep -qE "action write-chars --pane-id terminal_${PANE_NUM} " "$MOCK_LOG" \
  || fail "opt-in did not write-chars to terminal_${PANE_NUM} (numeric->terminal_ translation or awk matcher not exercised)"
grep -qE "action write --pane-id terminal_${PANE_NUM} 13$" "$MOCK_LOG" \
  || fail 'opt-in sent text but never sent Enter as byte 13'
(( fails == before )) && printf 'PASS: explicit opt-in injects into the resolved terminal_%s pane\n' "$PANE_NUM"

if (( fails > 0 )); then
  printf 'zellij-doorbell-safety test: FAIL (%d)\n' "$fails" >&2
  exit 1
fi
printf 'zellij-doorbell-safety test: PASS\n'
