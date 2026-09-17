#!/usr/bin/env bash
# Zellij doorbell adapter — doorbell-outcome v=1 emitter.
# The letter is already durable; this rings a live pane and reports ONE
# machine-readable outcome line on stdout (the wrapper owns forwarding).
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
set -uo pipefail

to="${1:?recipient}"
type="${2:?type}"
# Herdr-compatible argv: $3=slug (opaque/unused for line), $4=token when present.
# Legacy 3-arg form still accepted: $3=id_or_slug, token derived.
id_or_slug="${3:-}"
token_arg="${4:-}"

# doorbell-outcome v=1: exactly one line, validated before printing.
# outcome ∈ {submitted, pasted_not_submitted, no_live_surface}; reason/target
# cross-checked per the contract (no_live_surface always target=-; submitted
# and pasted always target=<pinned pane>, reason=- or enter_failed|-).
emit_outcome() { # $1=outcome $2=reason $3=target
    local outcome="$1" reason="$2" target="$3"
    case "$outcome" in
        submitted)
            [[ "$reason" == "-" && "$target" != "-" ]] || return 1
            [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
            ;;
        pasted_not_submitted)
            case "$reason" in enter_failed|-) ;; *) return 1;; esac
            [[ "$target" != "-" ]] || return 1
            [[ "$target" =~ ^[A-Za-z0-9._:+-]+$ || "$target" =~ ^%[0-9]+$ ]] || return 1
            ;;
        no_live_surface)
            [[ "$reason" != "-" && "$reason" =~ ^[A-Za-z0-9._:+-]+$ ]] || return 1
            [[ "$target" == "-" ]] || return 1
            ;;
        *) return 1;;
    esac
    printf 'doorbell-outcome v=1 outcome=%s reason=%s target=%s\n' \
        "$outcome" "$reason" "$target"
}

# Bounded call: 124 = actual timeout (runner-killed; the sentinel is
# runner-owned — a child exiting 124 itself is remapped to 123), 125 = runner
# (python3) unavailable, 127 = missing binary, else the child's exit code.
# Runner presence is verified up front, so a 124 at a classification point
# is always a genuine timeout — never ambiguous.
bounded_cmd() { # $1=seconds, rest=argv
    local secs="$1"; shift
    command -v python3 >/dev/null 2>&1 || return 125
    python3 -c '
import os, signal, subprocess, sys
try:
    p = subprocess.Popen(sys.argv[2:], start_new_session=True)
except FileNotFoundError:
    sys.exit(127)
try:
    rc = p.wait(timeout=float(sys.argv[1]))
except subprocess.TimeoutExpired:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except Exception:
        p.kill()
    p.wait()
    sys.exit(124)
# The runner owns the 124 sentinel: a child that exits 124 on its own was
# NOT killed on timeout and must not be read as one — remap to 123.
sys.exit(123 if rc == 124 else rc)
' "$secs" "$@"
}

zellij_bin="${ZELLIJ_BIN_PATH:-zellij}"
command -v "$zellij_bin" >/dev/null 2>&1 || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }
# Runner presence is verified BEFORE any 124 is read as a timeout: a missing
# python3 is adapter_unavailable (non-retryable), never helper_timeout.
command -v python3 >/dev/null 2>&1 || { emit_outcome no_live_surface adapter_unavailable -; exit 0; }

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
if [[ "$token_arg" =~ ^[0-9a-f]{8}$ ]]; then
  tok="$token_arg"
else
  tok="$(doorbell_token_for_id "$id_or_slug")"
fi
# Ruling 5 middle insert: name the durable letter's sender, but only when the
# wrapper supplied a value that passes the safe-identifier regex (re-checked
# here — env is never trusted). Otherwise the line stays the old shape.
line_from="${LETTERBOX_DOORBELL_FROM:-}"
if [[ "$line_from" =~ ^[A-Za-z][A-Za-z0-9._-]{0,31}$ ]]; then
  line="${prefix}${type} from ${line_from} in ${root}/${to}/inbox/${tail}"
else
  line="${prefix}${type} in ${root}/${to}/inbox/${tail}"
fi
if [[ -n "$tok" ]]; then
  line="${line} · ${tok}"
fi

bound_s="${LETTERBOX_DOORBELL_TIMEOUT:-1}"

pane_token() {
  local id="$1"
  if [[ "$id" =~ ^[0-9]+$ ]]; then
    printf 'terminal_%s' "$id"
  else
    printf '%s' "$id"
  fi
}

# 0 = live, 1 = dead, 124 = lookup timeout (retryable, pre-inject).
pane_live() {
  local p="$1" sess="${2:-}"
  local token list list_ec=0
  token="$(pane_token "$p")"
  if [[ -n "$sess" ]]; then
    list="$(bounded_cmd "$bound_s" "$zellij_bin" -s "$sess" action list-panes 2>/dev/null)" || list_ec=$?
  else
    list="$(bounded_cmd "$bound_s" "$zellij_bin" action list-panes 2>/dev/null)" || list_ec=$?
  fi
  if [[ "$list_ec" -eq 124 ]]; then
    return 124
  fi
  if [[ "$list_ec" -ne 0 ]]; then
    return 1
  fi
  printf '%s\n' "$list" | awk -v t="$token" -v raw="$p" '
    $1 == t || $1 == raw || $1 == ("terminal_" raw) { found = 1 }
    END { exit !found }
  '
}

pane_id=''
session=''

# 1) Live registry
registry_file="${LETTERBOX_ZELLIJ_REGISTRY:-}"
if [[ -z "$registry_file" && -n "${LETTERBOX_DIR:-}" ]]; then
  registry_file="$LETTERBOX_DIR/zellij-agents.tsv"
fi
if [[ -n "$registry_file" && -r "$registry_file" ]]; then
  while IFS=$'\t' read -r agent pane sess _ts || [[ -n "${agent:-}" ]]; do
    [[ "$agent" == "$to" && -n "${pane:-}" ]] || continue
    live_ec=0
    pane_live "$pane" "${sess:-}" || live_ec=$?
    if [[ "$live_ec" -eq 124 ]]; then
      emit_outcome no_live_surface helper_timeout -
      exit 0
    fi
    if [[ "$live_ec" -eq 0 ]]; then
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
      live_ec=0
      pane_live "$pane" "${sess:-}" || live_ec=$?
      if [[ "$live_ec" -eq 124 ]]; then
        emit_outcome no_live_surface helper_timeout -
        exit 0
      fi
      if [[ "$live_ec" -eq 0 ]]; then
        pane_id="$pane"
        session="${sess:-}"
        break
      fi
    done < "$patterns_file"
  fi
fi

[[ -n "$pane_id" ]] || { emit_outcome no_live_surface surface_not_found -; exit 0; }

token="$(pane_token "$pane_id")"

# Bounded inject on the pinned pane token (session-scoped when registered).
run_zellij() {
  if [[ -n "$session" ]]; then
    bounded_cmd "$bound_s" "$zellij_bin" -s "$session" "$@"
  else
    bounded_cmd "$bound_s" "$zellij_bin" "$@"
  fi
}

# Input injection is explicit opt-in: Enter can submit unrelated buffer text.
if [[ "${LETTERBOX_ZELLIJ_SUBMIT:-0}" == 1 ]]; then
  send_ec=0
  run_zellij action write-chars --pane-id "$token" "$line" >/dev/null || send_ec=$?
  if [[ "$send_ec" -ne 0 ]]; then
    if [[ "$send_ec" -eq 124 ]]; then
      # Text step started; bytes may or may not have been injected.
      emit_outcome no_live_surface unconfirmed -
    else
      emit_outcome no_live_surface send_failed -
    fi
    exit 0
  fi
  enter_ec=0
  run_zellij action write --pane-id "$token" 13 >/dev/null || enter_ec=$?
  if [[ "$enter_ec" -ne 0 ]]; then
    if [[ "$enter_ec" -eq 124 ]]; then
      # Enter may have landed after text was confirmed sent.
      emit_outcome no_live_surface unconfirmed -
    else
      emit_outcome pasted_not_submitted enter_failed "$token"
    fi
    exit 0
  fi
  emit_outcome submitted - "$token"
else
  # Durable mail still lands; without SUBMIT there is no terminal ring.
  emit_outcome no_live_surface notify_only -
fi
