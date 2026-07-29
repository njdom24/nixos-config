#!/usr/bin/env bash

get_clients() {
  mmsg get all-clients
}

clients_json="$(get_clients)"

# Grab the single truly-focused client's id, monitor, and floating state.
read -r current_id current_monitor current_floating < <(
  jq -r '[.clients[] | select(.is_focused == true)][0] |
     "\(.id) \(.monitor) \(.is_floating)"' <<<"$clients_json"
)

if [[ -z "${current_id:-}" || "$current_id" == "null" ]]; then
  exit 0
fi

if [[ "$current_floating" == "true" ]]; then
  target="false"
else
  target="true"
fi

# Bail out with zero focus changes unless a window of the target type
# exists, visible, on the SAME monitor as the focused window.
match_exists="$(jq --arg t "$target" --arg mon "$current_monitor" \
  '[.clients[] | select(.is_visible == true and .monitor == $mon and (.is_floating | tostring) == $t)] | length > 0' \
  <<<"$clients_json")"

if [[ "$match_exists" != "true" ]]; then
  exit 0
fi

# A match exists on this monitor; walk the stack with focusstack,next
# until we land on a same-monitor window of the target type. Bounded by
# total visible client count as a safety net against an infinite loop.
total="$(jq '[.clients[] | select(.is_visible == true)] | length' <<<"$clients_json")"

for ((i = 0; i < total; i++)); do
  mmsg dispatch focusstack,next
  clients_json="$(get_clients)"

  read -r new_monitor new_floating < <(
    jq -r '[.clients[] | select(.is_focused == true)][0] |
       "\(.monitor) \(.is_floating)"' <<<"$clients_json"
  )

  if [[ "$new_monitor" == "$current_monitor" && "$new_floating" == "$target" ]]; then
    exit 0
  fi
done

exit 0
