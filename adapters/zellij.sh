#!/usr/bin/env bash
# Zellij doorbell adapter (local automatic live-agent ring).
#
# Lookup order:
#   1) LETTERBOX_ZELLIJ_REGISTRY (default: $LETTERBOX_DIR/zellij-agents.tsv)
#      agent<TAB>pane_id<TAB>session_name<TAB>registered_at
#   2) LETTERBOX_ZELLIJ_PATTERNS (static fallback)
#      agent<TAB>pane_id<TAB>session_name
#
# Submit is opt-in: LETTERBOX_ZELLIJ_SUBMIT=1 injects generic doorbell text
# plus Enter (byte 13) via Zellij 0.44.x:
#   zellij -s <session> action write-chars --pane-id <id> <text>
#   zellij -s <session> action write --pane-id <id> 13
#
# Arg 3 is letter id (preferred) for v0.3 additive token. Legacy slug still
# accepted: token is derived when the arg looks like an id, else omitted.
set -euo pipefail

to="${1:?recipient}"
type="${2:?type}"
id_or_slug="${3:?id-or-slug}"

zellij_bin="${ZELLIJ_BIN_PATH:-zellij}"
command -v "$zellij_bin" >/dev/null 2>&1 || {
  echo 'zellij doorbell deferred: zellij is unavailable' >&2
  exit 0
}

# Token from letter id tail (8 hex) or hash; never slug/body.
doorbell_token_for_id() {
  local id="$1" tail
  tail="${id##*-}"
  if [[ "$tail" =~ ^[0-9a-f]{8}$ ]]; then
    printf '%s' "$tail"
    return 0
  fi
  if [[ "$id" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    printf '%s' "$id" | shasum -a 256 2>/dev/null | awk '{print substr($1,1,8)}' \
      || printf '%s' "$id" | sha256sum 2>/dev/null | awk '{print substr($1,1,8)}' \
      || printf '%s' "$id" | openssl dgst -sha256 2>/dev/null | awk '{print substr($NF,1,8)}'
    return 0
  fi
  # legacy slug-only call: no token (v0.2 line)
  printf ''
}

root="${LETTERBOX_DIR:?set LETTERBOX_DIR}"
prefix="📬 letterbox doorbell: unacked "
tail=" — please check"
tok="$(doorbell_token_for_id "$id_or_slug")"
if [[ -n "$tok" ]]; then
  line="${prefix}${type} in ${root}/${to}/inbox/${tail} · ${tok}"
else
  line="${prefix}${type} in ${root}/${to}/inbox/${tail}"
fi

pane_id=''
session=''

pane_token() {
  local id="$1"
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    printf 'terminal_%s' "$id"
  else
    printf '%s' "$id"
  fi
}

pane_live() {
  local p="$1" sess="${2:-}"
  local token list
  token="$(pane_token "$p")"
  if [[ -n "$sess" ]]; then
    list="$("$zellij_bin" -s "$sess" action list-panes 2>/dev/null || true)"
  else
    list="$("$zellij_bin" action list-panes 2>/dev/null || true)"
  fi
  printf '%s\n' "$list" | awk -v t="$token" -v raw="$p" '
    $1 == t || $1 == raw || $1 == ("terminal_" raw) { found = 1 }
    END { exit !found }
  '
}

# 1) Live registry
registry_file="${LETTERBOX_ZELLIJ_REGISTRY:-}"
if [[ -z "$registry_file" && -n "${LETTERBOX_DIR:-}" ]]; then
  registry_file="$LETTERBOX_DIR/zellij-agents.tsv"
fi
if [[ -n "$registry_file" && -r "$registry_file" ]]; then
  while IFS=$'\t' read -r agent pane sess _ts || [[ -n "${agent:-}" ]]; do
    [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
    if pane_live "$pane" "${sess:-}"; then
      pane_id="$pane"
      session="${sess:-}"
      break
    fi
  done < "$registry_file"
fi

# 2) Static patterns fallback
if [[ -z "$pane_id" ]]; then
  patterns_file="${LETTERBOX_ZELLIJ_PATTERNS:-}"
  if [[ -z "$patterns_file" && -n "${LETTERBOX_DIR:-}" ]]; then
    patterns_file="$LETTERBOX_DIR/zellij-patterns.tsv"
  fi
  if [[ -n "$patterns_file" && -r "$patterns_file" ]]; then
    while IFS=$'\t' read -r agent pane sess || [[ -n "${agent:-}" ]]; do
      [[ "$agent" == \#* || -z "${agent:-}" ]] && continue
      [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
      if pane_live "$pane" "${sess:-}"; then
        pane_id="$pane"
        session="${sess:-}"
        break
      fi
    done < "$patterns_file"
  fi
fi

if [[ -z "$pane_id" ]]; then
  echo "zellij doorbell deferred: no live zellij pane for $to" >&2
  # Observable outcome class (not attention):
  printf 'no_live_surface\n' >&2
  exit 0
fi

token="$(pane_token "$pane_id")"

run_zellij() {
  if [[ -n "$session" ]]; then
    "$zellij_bin" -s "$session" "$@"
  else
    "$zellij_bin" "$@"
  fi
}

if [[ "${LETTERBOX_ZELLIJ_SUBMIT:-0}" == 1 ]]; then
  if run_zellij action write-chars --pane-id "$token" "$line" >/dev/null \
    && run_zellij action write --pane-id "$token" 13 >/dev/null; then
    printf 'zellij doorbell submitted to %s on %s (session %s)\n' "$to" "$token" "${session:-default}"
  else
    printf 'zellij doorbell pasted_not_submitted for %s on %s\n' "$to" "$token" >&2
  fi
else
  # Durable mail still lands; without SUBMIT there is no terminal ring.
  printf 'zellij target live for %s on %s; set LETTERBOX_ZELLIJ_SUBMIT=1 to inject the doorbell (submit-off = durable only, no ring)\n' "$to" "$token"
fi
