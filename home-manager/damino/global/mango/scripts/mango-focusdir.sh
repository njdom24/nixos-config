#!/usr/bin/env bash

EDGE_TOLERANCE="20"

dir="${1:-}"
case "$dir" in
  up|down|left|right) ;;
  *) echo "usage: $0 {up|down|left|right}" >&2; exit 1 ;;
esac

do_focus() {
  mmsg dispatch focusdir,"$dir"
  exit 0
}

do_focus_monitor() {
  local mon="$1" reason="$2"
  mmsg dispatch focusmon,"$mon"
  exit 0
}

client_json="$(mmsg get focusing-client)"
if ! echo "$client_json" | jq -e '.x != null and .y != null' >/dev/null 2>&1; then
  do_focus "no focused client info, deferring to focusdir"
fi

read -r cx cy cw ch cur_mon_name cur_id <<< "$(echo "$client_json" | jq -r '"\(.x) \(.y) \(.width) \(.height) \(.monitor) \(.id)"')"
ccx=$((cx + cw / 2))
ccy=$((cy + ch / 2))

is_fullscreen="$(echo "$client_json" | jq -r '.is_fullscreen == true')"

if [ "$is_fullscreen" = "true" ]; then
    has_candidate="false"
else
  all_clients_json="$(mmsg get all-clients)"
  has_candidate="$(echo "$all_clients_json" | jq -r \
    --argjson ccx "$ccx" --argjson ccy "$ccy" --arg dir "$dir" \
    --arg mon "$cur_mon_name" --argjson curid "$cur_id" '
    [ .clients[]
      | select(.monitor == $mon)
      | select(.id != $curid)
      | select(.is_visible == true)
      | . as $c
      | (($c.x) + ($c.width / 2)) as $x2
      | (($c.y) + ($c.height / 2)) as $y2
      | select(
        if $dir == "left" then $x2 < $ccx
        elif $dir == "right" then $x2 > $ccx
        elif $dir == "up" then $y2 < $ccy
        else $y2 > $ccy
        end
      )
    ] | length > 0
  ')"
fi

if [ "$has_candidate" = "true" ]; then
  do_focus "found a candidate in the current tag"
fi

# Only proceed if we're at the monitor
# edge and there's an adjacent monitor that direction.
mon_json="$(mmsg get all-monitors)"
cur_mon="$(echo "$mon_json" | jq -c --arg n "$cur_mon_name" '.monitors[] | select(.name == $n)')"
if [ -z "$cur_mon" ]; then
  exit 0
fi

read -r mx my mw mh <<< "$(echo "$cur_mon" | jq -r '"\(.x) \(.y) \(.width) \(.height)"')"

at_edge=0
if [ "$is_fullscreen" = "true" ]; then
  at_edge=1
else
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
fi

if [ "$at_edge" != 1 ]; then
  exit 0
fi

neighbor="$(echo "$mon_json" | jq -r \
  --arg dir "$dir" --arg cur "$cur_mon_name" \
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

if [ -z "$neighbor" ]; then
  exit 0
fi

do_focus_monitor "$neighbor" "at edge with adjacent monitor $neighbor"