#!/usr/bin/env bash
# Mutation: the private-vocabulary gate must catch residue wherever it lands —
# visible file, hidden dotfile, and .github workflow — failing with file:line.
# Also asserts the gate PASSes on a clean tree (explicit clean-tree check).
# Labels all mutation output so a clean outer make test cannot be confused with
# a mutation failure.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
gate_name="test_no_private_vocabulary.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vocab-mut.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Self-contained copy of the repo (including .git so ls-files enumeration runs).
cp -R "$root"/. "$tmp/repo/"

# --- Explicit clean-tree gate PASS assertion (parity requirement) ---
clean_out="$(mktemp)"
set +e
( cd "$tmp/repo" && "./tests/$gate_name" ) >"$clean_out" 2>&1
clean_rc=$?
set -e
echo "CLEAN-TREE gate rc=$clean_rc"
sed 's/^/CLEAN-TREE | /' "$clean_out"
if [[ "$clean_rc" -ne 0 ]] || ! grep -qE 'private-vocabulary: PASS' "$clean_out"; then
  echo "FAIL: gate did not PASS on clean tree (rc=$clean_rc)" >&2
  cat "$clean_out" >&2
  rm -f "$clean_out"
  exit 1
fi
echo "PASS: clean-tree gate PASS"
rm -f "$clean_out"

plant_and_run() { # $1 relative residue path
  local rel="$1" out rc
  mkdir -p "$tmp/repo/$(dirname "$rel")"
  # Build forbidden token from parts so THIS file is not itself a residue hit.
  printf 'residue tele''gram here\n' > "$tmp/repo/$rel"
  git -C "$tmp/repo" add -f "$rel" 2>/dev/null || true
  out="$(mktemp)"
  set +e
  ( cd "$tmp/repo" && "./tests/$gate_name" ) >"$out" 2>&1
  rc=$?
  set -e
  echo "MUTATION/[mut] residue at $rel → gate rc=$rc"
  # Indent mutation output so outer scanners don't confuse it with clean-run failure
  sed 's/^/MUTATION\/[mut] | /' "$out"
  git -C "$tmp/repo" rm -q --cached "$rel" 2>/dev/null || true
  rm -f "$tmp/repo/$rel"
  rm -f "$out"
  return "$rc"
}

fails=0
for rel in "docs/visible-residue.md" ".github/workflows/residue-ci.yml" ".hidden-residuerc"; do
  if plant_and_run "$rel"; then
    echo "FAIL: gate passed with residue at $rel" >&2
    fails=$((fails+1))
  else
    echo "PASS: gate failed on residue at $rel"
  fi
done

mkdir -p "$tmp/repo/docs"
printf 'residue shared''\n''brain here\n' > "$tmp/repo/docs/wrap-residue.md"
git -C "$tmp/repo" add -f docs/wrap-residue.md 2>/dev/null || true
wrap="$(cd "$tmp/repo" && "./tests/$gate_name" 2>&1)" && wrap_rc=0 || wrap_rc=$?
if [[ "$wrap_rc" -eq 0 ]]; then
  echo "FAIL: gate passed with wrapped private phrase" >&2
  fails=$((fails+1))
elif [[ "$wrap" != *"docs/wrap-residue.md:"* ]]; then
  echo "FAIL: wrap hit missing file:line" >&2
  fails=$((fails+1))
else
  echo "PASS: gate failed on wrapped phrase"
fi
git -C "$tmp/repo" rm -q --cached docs/wrap-residue.md 2>/dev/null || true
rm -f "$tmp/repo/docs/wrap-residue.md"

# file:line evidence on a representative visible-residue case
mkdir -p "$tmp/repo/docs"
printf 'residue tele''gram here\n' > "$tmp/repo/docs/visible-residue.md"
git -C "$tmp/repo" add -f docs/visible-residue.md 2>/dev/null || true
hit="$(cd "$tmp/repo" && "./tests/$gate_name" 2>&1 || true)"
echo "MUTATION/[mut] file:line evidence run:"
echo "$hit" | sed 's/^/MUTATION\/[mut] | /'
if [[ "$hit" == *"docs/visible-residue.md:1:"* ]]; then
  echo "PASS: hit carries file:line"
else
  echo "FAIL: hit missing file:line: $hit" >&2
  fails=$((fails+1))
fi

# Cleanup planted residue so we leave the copy clean
git -C "$tmp/repo" rm -q --cached docs/visible-residue.md 2>/dev/null || true
rm -f "$tmp/repo/docs/visible-residue.md"

if [[ "$fails" -ne 0 ]]; then
  echo "vocabulary-gate mutation: FAIL ($fails)" >&2
  exit 1
fi
echo "vocabulary-gate mutation: PASS"
exit 0