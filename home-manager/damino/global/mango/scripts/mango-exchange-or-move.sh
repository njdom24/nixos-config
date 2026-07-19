#!/usr/bin/env bash

EDGE_TOLERANCE="20"

dir="${1:-}"
case "$dir" in
  up|down|left|right) ;;
  *) echo "usage: $0 {up|down|left|right}" >&2; exit 1 ;;
esac

fallback() {
  mmsg dispatch exchange_client,"$dir"
  exit 0
}

# Exclude HEADLESS (unless no others exist)
all_monitors_json() {
  local json
  json="$(mmsg get all-monitors)"

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

client_json="$(mmsg get focusing-client)"
echo "$client_json" | jq -e '.x != null and .y != null' >/dev/null 2>&1 || fallback "no valid client geometry"

mon_json="$(all_monitors_json)"
cur_name="$(echo "$mon_json" | jq -r '.monitors[] | select(.active == true) | .name')"
[ -n "$cur_name" ] || fallback "could not determine focused monitor"
cur_mon="$(echo "$mon_json" | jq -c --arg n "$cur_name" '.monitors[] | select(.name == $n)')"

read -r cx cy cw ch <<< "$(echo "$client_json" | jq -r '"\(.x) \(.y) \(.width) \(.height)"')"
read -r mx my mw mh <<< "$(echo "$cur_mon" | jq -r '"\(.x) \(.y) \(.width) \(.height)"')"

at_edge=0
case "$dir" in
  left)
    if [ "$cx" -le "$((mx + EDGE_TOLERANCE))" ]; then at_edge=1; fi
    ;;
  right)
    if [ "$((cx + cw))" -ge "$((mx + mw - EDGE_TOLERANCE))" ]; then at_edge=1; fi
    ;;
  up)
    if [ "$cy" -le "$((my + EDGE_TOLERANCE))" ]; then at_edge=1; fi
    ;;
  down)
    if [ "$((cy + ch))" -ge "$((my + mh - EDGE_TOLERANCE))" ]; then at_edge=1; fi
    ;;
esac

[ "$at_edge" = 1 ] || fallback "not at edge"

# Find the nearest monitor positioned in that direction relative to the
# current monitor's edge.
neighbor="$(echo "$mon_json" | jq -r \
  --arg dir "$dir" --arg cur "$cur_name" \
  --argjson mx "$mx" --argjson my "$my" --argjson mw "$mw" --argjson mh "$mh" '
  .monitors
  | map(select(.name != $cur))
  | map(select(
    if $dir == "left" then (.x + .width) <= $mx
    elif $dir == "right" then .x >= ($mx + $mw)
    elif $dir == "up" then (.y + .height) <= $my
    else .y >= ($my + $mh)
    end
  ))
  | (if $dir == "left" then sort_by(-(.x + .width))
    elif $dir == "right" then sort_by(.x)
    elif $dir == "up" then sort_by(-(.y + .height))
    else sort_by(.y)
    end)
  | .[0].name // empty
')"

[ -n "$neighbor" ] || fallback "no adjacent monitor found in direction $dir"

# Use active tag on the destination monitor
dest_tag="$(echo "$mon_json" | jq -r --arg n "$neighbor" '.monitors[] | select(.name == $n) | .tags[] | select(.is_active == true) | .index' | head -n1)"
[ -n "$dest_tag" ] || fallback "could not determine active tag on neighbor monitor"

mmsg dispatch tagcrossmon,"${dest_tag}","${neighbor}"
mmsg dispatch focusmon,"${neighbor}"