#!/usr/bin/env bash
# Minimal ClickUp API v2 client for the Blockful GitHub integration.
#
# Subcommands:
#   status-order "<status string>"            -> prints the [N] order, or -1
#   get-status <task_id>                      -> ok=, status=, order=
#   set-status <task_id> "<status>"           -> ok=
#   set-status-guarded <task_id> "<status>"   -> ok=, applied= (skips when current order >= target order)
#   comment <task_id> "<text>"                -> ok=
#   mark-done-many "<ids newline-separated>" "<status>" -> loops set-status-guarded, single aggregated ok=
#
# Env: CLICKUP_TOKEN, CLICKUP_TEAM_ID (required for API subcommands)
# API failures never exit non-zero: they emit ::warning:: and ok=false.
set -uo pipefail

BASE="https://api.clickup.com/api/v2"
QS="custom_task_ids=true&team_id=${CLICKUP_TEAM_ID:-}"

req() { # method path [json_body]; body on stdout; non-2xx -> retry once -> warning + return 1
  local method="$1" path="$2" body="${3:-}" out http resp attempt
  local args=(-sS -X "$method" -H "Authorization: ${CLICKUP_TOKEN:-}" -H "Content-Type: application/json" -w $'\n%{http_code}' "$BASE$path")
  [ -n "$body" ] && args+=(-d "$body")
  for attempt in 1 2; do
    out="$(curl "${args[@]}" 2>/dev/null || true)"
    http="${out##*$'\n'}"
    resp="${out%$'\n'*}"
    if [ "${http:0:1}" = "2" ]; then printf '%s' "$resp"; return 0; fi
    [ "$attempt" = 1 ] && sleep 2
  done
  echo "::warning::ClickUp API $method $path failed (HTTP ${http:-n/a}): $(head -c 300 <<<"$resp")" >&2
  return 1
}

status_order() {
  if [[ "${1:-}" =~ ^\[([0-9]+)\] ]]; then echo "${BASH_REMATCH[1]}"; else echo "-1"; fi
}

get_status() { # task_id -> ok= status= order=
  local resp st
  if resp="$(req GET "/task/$1?$QS")"; then
    st="$(jq -r '.status.status // ""' <<<"$resp")"
    echo "ok=true"; echo "status=$st"; echo "order=$(status_order "$st")"
  else
    echo "ok=false"; echo "status="; echo "order=-1"
  fi
}

set_status() { # task_id status -> ok=
  if req PUT "/task/$1?$QS" "$(jq -n --arg s "$2" '{status: $s}')" >/dev/null; then
    echo "::notice::ClickUp: $1 -> $2" >&2
    echo "ok=true"
  else
    echo "ok=false"
  fi
}

set_status_guarded() { # task_id status; applies only when current order < target order (or unknown)
  local target_order current_order
  target_order="$(status_order "$2")"
  current_order="$(get_status "$1" | grep '^order=' | cut -d= -f2)"
  if [ "$current_order" != "-1" ] && [ "$target_order" != "-1" ] && [ "$current_order" -ge "$target_order" ]; then
    echo "::notice::ClickUp: $1 already at order $current_order (>= $target_order), skipping" >&2
    echo "ok=true"; echo "applied=false"
    return 0
  fi
  set_status "$1" "$2"
  echo "applied=true"
}

comment() { # task_id text -> ok=
  if req POST "/task/$1/comment?$QS" "$(jq -n --arg t "$2" '{comment_text: $t}')" >/dev/null; then
    echo "ok=true"
  else
    echo "ok=false"
  fi
}

mark_done_many() { # newline-separated ids, status -> single ok= line
  local all_ok=true task out
  while IFS= read -r task; do
    [ -n "$task" ] || continue
    out="$(set_status_guarded "$task" "$2")"
    grep -q '^ok=true' <<<"$out" || all_ok=false
  done <<<"$1"
  echo "ok=$all_ok"
}

usage() { echo "usage: clickup.sh status-order|get-status|set-status|set-status-guarded|comment|mark-done-many" >&2; exit 2; }

cmd="${1:-}"; shift || true
case "$cmd" in
  status-order)       status_order "${1:-}" ;;
  get-status)         [ $# -ge 1 ] || usage; get_status "$1" ;;
  set-status)         [ $# -ge 2 ] || usage; set_status "$1" "$2" ;;
  set-status-guarded) [ $# -ge 2 ] || usage; set_status_guarded "$1" "$2" ;;
  comment)            [ $# -ge 2 ] || usage; comment "$1" "$2" ;;
  mark-done-many)     [ $# -ge 2 ] || usage; mark_done_many "$1" "$2" ;;
  *) usage ;;
esac
