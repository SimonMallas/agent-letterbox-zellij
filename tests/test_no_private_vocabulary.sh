#!/usr/bin/env bash
# Mandatory private-vocabulary sweep (public product cleanliness).
# Separate from personal-data privacy tests. Baseline identical across
# agent-letterbox-{cmux,tmux,herdr,zellij} public v0.3 ports.
#
# Scans EVERY tracked file via `git ls-files -z` (hidden dirs, .github/
# workflows, root dotfiles included). Non-git fallback walks the tree
# including hidden paths. Fails with actual file:line for each hit.
#
# Forbidden baseline (do not weaken per-port):
#   shared-brain | bus doorbell | BUS_AGENT | BUS_DIR | telegram | launchd | kimik357 | utc_now
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
self="tests/$(basename "$0")"

# Patterns built from parts so this file is not a self-hit if ever scanned.
pat_shared_brain="shared""-brain"
pat_bus_doorbell="bus ""doorbell"
pat_bus_agent="BUS_""AGENT"
pat_bus_dir="BUS_""DIR"
pat_telegram="tele""gram"
pat_launchd="launch""d"
pat_kimik="kimik""357"
pat_utc_now="utc_""now"

# Extended regex alternation for a single pass (case-sensitive baseline as specified).
PATTERN="${pat_shared_brain}|${pat_bus_doorbell}|${pat_bus_agent}|${pat_bus_dir}|${pat_telegram}|${pat_launchd}|${pat_kimik}|${pat_utc_now}"

fails=0

scan_tracked() {
  # Every tracked file, including hidden and .github/. Null-delimited for safety.
  # Exclude only this gate script (patterns live here by necessity).
  local tmp f
  tmp="$(mktemp)"
  while IFS= read -r -d '' f; do
    [[ "$f" == "$self" ]] && continue
    [[ -f "$f" ]] || continue
    # -n line number, -I skip binary, -H always show filename, -E extended regex.
    # Do NOT use rg -I in a way that drops filenames.
    grep -nIHE -E -- "$PATTERN" "$f" 2>/dev/null || true
  done < <(git ls-files -z) >"$tmp"
  cat "$tmp"
  rm -f "$tmp"
}

scan_fallback() {
  # Non-git fallback: walk tree including hidden files/dirs; skip .git and this script.
  local tmp f
  tmp="$(mktemp)"
  if command -v rg >/dev/null 2>&1; then
    # -n line numbers, -H filenames, --hidden includes dotfiles.
    rg -nH --hidden --no-messages --glob '!.git/**' --glob "!$self" \
      -e "$pat_shared_brain" -e "$pat_bus_doorbell" \
      -e "$pat_bus_agent" -e "$pat_bus_dir" -e "$pat_telegram" -e "$pat_launchd" \
      -e "$pat_kimik" -e "$pat_utc_now" . 2>/dev/null >"$tmp" || true
  else
    while IFS= read -r -d '' f; do
      f="${f#./}"
      [[ "$f" == "$self" ]] && continue
      grep -nIHE -E -- "$PATTERN" "$f" 2>/dev/null || true
    done < <(find . -name .git -prune -o -type f -print0 2>/dev/null) >"$tmp"
  fi
  cat "$tmp"
  rm -f "$tmp"
}

echo "private-vocabulary sweep: scanning every tracked file (git ls-files -z)..."

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  out="$(scan_tracked)"
else
  echo "private-vocabulary: git unavailable — fallback walk (includes hidden)" >&2
  out="$(scan_fallback)"
fi

if [[ -n "$out" ]]; then
  printf 'FAIL [private-vocabulary] residue found (file:line):\n%s\n' "$out" >&2
  fails=$((fails + 1))
fi

if (( fails > 0 )); then
  printf 'private-vocabulary: FAIL (%d pattern group(s) hit)\n' "$fails" >&2
  exit 1
fi
printf 'private-vocabulary: PASS\n'
exit 0
