#!/usr/bin/env bash
# Mutation: early abort after first v0.3 assertion must be non-zero and must
# report count/footer failure (not a silent green under set -e).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
suite="$root/tests/test_lifecycle_v03.sh"

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

set +e
LETTERBOX_MUTATE_EARLY_ABORT=1 "$suite" >"$out" 2>&1
rc=$?
set -e

echo "--- mutation suite output ---"
cat "$out"
echo "--- mutation rc=$rc ---"

fails=0
if [[ "$rc" -eq 0 ]]; then
  echo "FAIL: early-abort mutation returned rc=0" >&2
  fails=$((fails+1))
fi
# Exact success footer line only (not the word PASS inside a FAIL diagnostic)
if grep -qxF 'lifecycle v0.3: PASS' "$out"; then
  echo "FAIL: early-abort mutation printed success footer" >&2
  fails=$((fails+1))
fi
if ! grep -qE 'lifecycle v0\.3: FAIL \(early abort|pass count|incomplete' "$out"; then
  echo "FAIL: early-abort mutation missing explicit count/footer failure" >&2
  fails=$((fails+1))
fi
# Must not have completed later assertion blocks
if grep -qF 'PASS: progress' "$out"; then
  echo "FAIL: mutation ran past first assertion block" >&2
  fails=$((fails+1))
fi
if ! grep -qF 'MUTATION: early abort after first v0.3 assertion' "$out"; then
  echo "FAIL: mutation hook did not fire" >&2
  fails=$((fails+1))
fi

if [[ "$fails" -ne 0 ]]; then
  echo "early-abort mutation: FAIL ($fails)" >&2
  exit 1
fi
echo "early-abort mutation: PASS"
exit 0
