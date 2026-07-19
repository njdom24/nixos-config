#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/mango-workspace-map"
touch "$STATE_FILE"

usage() {
  echo "usage: $0 {view|move} TAG" >&2
  echo "       $0 assign TAG MONITOR" >&2
  echo "       $0 unassign TAG" >&2
  exit 1
}

[ $# -ge 1 ] || usage
action="$1"

# --- state file helpers -----------------------------------------------
# format per line: TAG=MONITOR:TYPE   (TYPE is "manual" or "auto")

map_line() { grep "^${1}=" "$STATE_FILE" 2>/dev/null | tail -n1; }
map_mon()  { map_line "$1" | cut -d= -f2 | cut -d: -f1; }
map_type() { map_line "$1" | cut -d= -f2 | cut -d: -f2; }

map_set() {
  local tag="$1" mon="$2" type="$3"
  grep -v "^${tag}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
  echo "${tag}=${mon}:${type}" >> "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

map_unset() {
  local tag="$1"
  grep -v "^${tag}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
  mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# --- compositor queries -------------------------------------------------
# Single source of truth per invocation, to avoid multiple mmsg round trips
# and any chance of state changing between calls.
# Excludes HEADLESS (unless no others exist)
all_monitors_json() {
  local json
  json="$(mmsg get all-monitors)"

  # If any non-HEADLESS monitor is connected (has a valid mode), ignore
  # HEADLESS outputs. Otherwise, keep them so the script still works in a
  # fully headless session.
  if echo "$json" | jq -e '
    [.monitors[]
      | select((.name | startswith("HEADLESS-") | not)
        and .width > 0
        and .height > 0)]
    | length > 0
  ' >/dev/null; then
    echo "$json" | jq '
      {monitors: [.monitors[]
        | select(.name | startswith("HEADLESS-") | not)]}
    '
  else
      echo "$json"
  fi
}

current_monitor() {
  echo "$1" | jq -r '.monitors[] | select(.active == true) | .name' | head -n1
}

# Prints "TAGINDEX CLIENT_COUNT" for whichever tag is currently active on $2
active_tag_on_monitor() {
  local json="$1" mon="$2"
  echo "$json" | jq -r --arg m "$mon" \
    '.monitors[] | select(.name == $m) | .tags[] | select(.is_active == true) | "\(.index) \(.client_count)"' \
    | head -n1
}

# True if monitor $2 is currently connected/present in $1
monitor_exists() {
  local json="$1" mon="$2"
  echo "$json" | jq -e --arg m "$mon" '.monitors[] | select(.name == $m)' >/dev/null 2>&1
}

# --- main ----------------------------------------------------------------
case "$action" in
  assign)
    [ $# -ge 3 ] || usage
    map_set "$2" "$3" "manual"
    exit 0
    ;;
  unassign)
    [ $# -ge 2 ] || usage
    map_unset "$2"
    exit 0
    ;;
  view|move)
    [ $# -ge 2 ] || usage
    tag="$2"

    json="$(all_monitors_json)"

    # Capture where we are *before* doing anything, so "move" can jump
    # back here afterward (tagcrossmon follows the window to its new
    # monitor/tag, which we don't want for a plain "move").
    cur_mon="$(current_monitor "$json")"
    read -r cur_tag cur_clients <<< "$(active_tag_on_monitor "$json" "$cur_mon" || true)"

    existing_mon="$(map_mon "$tag" || true)"
    existing_type="$(map_type "$tag" || true)"

    if [ -n "${existing_mon:-}" ] && monitor_exists "$json" "$existing_mon"; then
      target_mon="$existing_mon"
    else
      # Either never assigned, or assigned to a monitor that's
      # currently disconnected. Fall back to the focused monitor for
      # this invocation.
      target_mon="$(current_monitor "$json")"
      [ -n "$target_mon" ] || { echo "could not determine focused monitor" >&2; exit 1; }

      if [ "${existing_type:-}" = "manual" ] && [ -n "${existing_mon:-}" ]; then
        # Keep the manual pin intact (e.g. "DP-2") so it resumes
        # automatically once that monitor reconnects. Just don't
        # dispatch to a monitor that doesn't exist right now.
        :
      else
        map_set "$tag" "$target_mon" "auto"
      fi
    fi

    if [ "$action" = "view" ]; then
      read -r prev_tag prev_clients <<< "$(active_tag_on_monitor "$json" "$target_mon")"
      mmsg dispatch viewcrossmon,"${tag}","${target_mon}"

      if [ -n "${prev_tag:-}" ] && [ "$prev_tag" != "$tag" ]; then
        prev_type="$(map_type "$prev_tag" || true)"
        if [ "${prev_clients:-0}" = "0" ] && [ "${prev_type:-}" = "auto" ]; then
          map_unset "$prev_tag"
        fi
      fi
    else
      mmsg dispatch tagcrossmon,"${tag}","${target_mon}"

      # tagcrossmon follows the moved window to its destination.
      # Focus back to where we were.
      if [ -n "${cur_mon:-}" ] && [ -n "${cur_tag:-}" ]; then
        mmsg dispatch viewcrossmon,"${cur_tag}","${cur_mon}"
        mmsg dispatch focusmon,"${cur_mon}"
      fi
    fi
    ;;
  *)
    usage
    ;;
esac