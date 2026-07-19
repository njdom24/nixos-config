#!/usr/bin/env bash
# https://github.com/mangowm/mango/issues/990#issuecomment-4582776345

tag="$1"
monitor="$2"
appid="$3"
shift 3

orig_monitor=$(mmsg get focusing-client | sed -n 's/.*"monitor":"\([^"]*\)".*/\1/p')
orig_tag=$(mmsg get all-tags | jq -r --arg mon "$orig_monitor" \
  '.all_tags[] | select(.monitor == $mon) | .tags[] | select(.is_active) | .index')

"$@" &
line=$(mmsg watch focusing-client | grep -m1 "\"appid\":\"$appid\"")
id=$(echo "$line" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
mmsg dispatch "tagcrossmon,$tag,$monitor" "client,$id"
mmsg dispatch "viewcrossmon,$orig_tag,$orig_monitor"`