#!/usr/bin/env bash
# Catch accidental create/overwrite/large-deletion of skills/agent-letterbox/SKILL.md.
# Public porting rule: amend in place; preserve frontmatter authorship/license.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
skill="skills/agent-letterbox/SKILL.md"

[[ -f "$skill" ]] || { echo "FAIL: $skill missing" >&2; exit 1; }

base_ref=""
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  base_ref="$(git merge-base HEAD origin/main 2>/dev/null || true)"
fi
if [[ -z "$base_ref" ]] && git rev-parse --verify main >/dev/null 2>&1; then
  base_ref="$(git merge-base HEAD main 2>/dev/null || true)"
fi
if [[ -z "$base_ref" ]]; then
  base_ref="$(git rev-list --max-parents=0 HEAD | tail -1)"
fi

if git cat-file -e "${base_ref}:skills/agent-letterbox/SKILL.md" 2>/dev/null; then
  base_tmp="$(mktemp)"
  git show "${base_ref}:skills/agent-letterbox/SKILL.md" >"$base_tmp"
  base_lines="$(wc -l < "$base_tmp" | tr -d ' ')"
  head_lines="$(wc -l < "$skill" | tr -d ' ')"
  min_keep=$(( base_lines * 75 / 100 ))
  if (( head_lines < min_keep )) || (( base_lines - head_lines > 30 && head_lines < base_lines )); then
    echo "FAIL: $skill shrank too much vs $base_ref (base=$base_lines head=$head_lines)" >&2
    git diff --stat "$base_ref" -- "$skill" >&2 || true
    rm -f "$base_tmp"
    exit 1
  fi
  for key in name description author license; do
    base_val="$(awk -v k="$key" 'BEGIN{fm=0} /^---$/{fm++; next} fm==1 && $0 ~ "^"k": "{sub(/^[^:]+:[[:space:]]*/,""); print; exit}' "$base_tmp")"
    head_val="$(awk -v k="$key" 'BEGIN{fm=0} /^---$/{fm++; next} fm==1 && $0 ~ "^"k": "{sub(/^[^:]+:[[:space:]]*/,""); print; exit}' "$skill")"
    if [[ -n "$base_val" && "$base_val" != "$head_val" ]]; then
      echo "FAIL: frontmatter $key changed ('$base_val' -> '$head_val')" >&2
      rm -f "$base_tmp"
      exit 1
    fi
  done
  rm -f "$base_tmp"
fi

head -20 "$skill" | grep -q '^name: ' || { echo "FAIL: missing name frontmatter" >&2; exit 1; }
head -20 "$skill" | grep -q '^description: ' || { echo "FAIL: missing description frontmatter" >&2; exit 1; }
head -20 "$skill" | grep -q '^author: ' || { echo "FAIL: missing author frontmatter" >&2; exit 1; }
head -20 "$skill" | grep -q '^license: ' || { echo "FAIL: missing license frontmatter" >&2; exit 1; }
head -5 "$skill" | grep -qx -- '---' || { echo "FAIL: missing frontmatter start" >&2; exit 1; }

echo "skill-preserve: PASS ($skill kept; no large deletion vs ${base_ref:-none})"
exit 0
