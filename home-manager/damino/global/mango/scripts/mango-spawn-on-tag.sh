#!/usr/bin/env bash
# https://github.com/mangowm/mango/issues/990#issuecomment-4582776345

tag="$1"
monitor="$2"
appid="$3"
shift 3

orig_monitor=$(mmsg get focusing-client | sed -n 's/.*"monitor":"\([^"]*\)".*/\1/p')
orig_tag=$(mmsg get all-tags | jq -r --arg mon "$orig_monitor" \
  '.all_tags[] | select(.monitor == $mon) | .tags[] | select(.is_active) | .index')

# Snapshot ids that already exist for this appid, so we don't react to them
mapfile -t existing_ids < <(mmsg get all-clients | jq -r --arg appid "$appid" \
  '.clients[] | select(.appid == $appid) | .id')

declare -A seen
for id in "${existing_ids[@]}"; do
  seen[$id]=1
done

"$@" &

while IFS= read -r line; do
  # Extract every id belonging to this appid from the snapshot line
  ids=$(echo "$line" | jq -r --arg appid "$appid" \
    '.clients[]? | select(.appid == $appid) | .id' 2>/dev/null)

  for id in $ids; do
    if [ -z "${seen[$id]}" ]; then
      seen[$id]=1
      mmsg dispatch "tagcrossmon,$tag,$monitor" "client,$id"
      mmsg dispatch "viewcrossmon,$orig_tag,$orig_monitor"
    fi
  done
done < <(timeout 60 stdbuf -oL mmsg watch all-clients)
