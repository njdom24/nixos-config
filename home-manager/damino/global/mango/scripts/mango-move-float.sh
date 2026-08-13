#!/usr/bin/env bash

dx="${1:?usage: $0 <dx> <dy>}"
dy="${2:?usage: $0 <dx> <dy>}"

is_floating="$(mmsg get focusing-client | jq -r '.is_floating')"

[[ "$is_floating" == "true" ]] || exit 0

mmsg dispatch "movewin,$dx,$dy"
