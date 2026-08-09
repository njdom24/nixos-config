#!/usr/bin/env bash

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <monitor> [monitor...]" >&2
  exit 1
fi

WHITELIST=("$@")
LOCKFILE="${XDG_RUNTIME_DIR}/mango_vrr_lock"
rm -f "$LOCKFILE"

declare -A prev_fs
whitelist_json=$(printf '%s\n' "${WHITELIST[@]}" | jq -R . | jq -s .)

mmsg watch all-clients | while IFS= read -r line; do
  while IFS=$'\t' read -r monitor fs; do
    old="${prev_fs[$monitor]:-false}"
    if [[ "$fs" != "$old" ]]; then
      if [[ -e "$LOCKFILE" ]]; then
        continue
      fi

      if [[ "$fs" == "true" ]]; then
        echo "[$monitor] entered fullscreen — enabling adaptive sync"
        wlr-randr --output "$monitor" --adaptive-sync enabled
      else
        echo "[$monitor] exited fullscreen — disabling adaptive sync"
        wlr-randr --output "$monitor" --adaptive-sync disabled
      fi
      prev_fs[$monitor]="$fs"
    fi
  done < <(echo "$line" | jq -r --argjson wl "$whitelist_json" '
    .clients
    | group_by(.monitor)
    | map({monitor: .[0].monitor, fs: (any(.[]; .is_visible and .is_fullscreen))})
    | .[] | select(.monitor as $m | $wl | index($m))
    | [.monitor, .fs] | @tsv
  ')
done
