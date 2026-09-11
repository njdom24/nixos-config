#!/usr/bin/env bash
# mango-autotiling.sh — set dwindle split axis based on the focused
# window's aspect ratio, similar to sway's autotiling.
# Requires dwindle_manual_split=1

mmsg watch focusing-client | while read -r line; do
  width=$(jq -r '.width // .geometry.width // empty' <<<"$line")
  height=$(jq -r '.height // .geometry.height // empty' <<<"$line")

  [[ -z "$width" || -z "$height" ]] && continue

  if (( width >= height )); then
    mmsg dispatch dwindle_split_horizontal
  else
    mmsg dispatch dwindle_split_vertical
  fi
done
