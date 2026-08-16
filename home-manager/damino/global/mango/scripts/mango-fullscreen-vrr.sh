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

# Snapshot monitor resolutions once at startup. Used as a fallback signal:
# gamescope (and similar nested-compositor apps) create a borderless surface
# exactly the size of the target output but never reliably assert
# is_fullscreen at steady state, so geometry match is the only stable signal
# for that class of client.
monitor_res_json=$(mmsg get all-monitors | jq '
  [.monitors[] | select(.name != null) | {(.name): {w: .width, h: .height}}]
  | add // {}
')

mmsg watch all-clients | while IFS= read -r line; do
  while IFS=$'\t' read -r monitor fs; do
    old="${prev_fs[$monitor]:-false}"
    if [[ "$fs" != "$old" ]]; then
      # Always record the new state, even if we can't act on it right now,
      # so a transient lock never permanently swallows an edge.
      prev_fs[$monitor]="$fs"

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
    fi
  done < <(echo "$line" | jq -r --argjson wl "$whitelist_json" --argjson mres "$monitor_res_json" '
    .clients
    | group_by(.monitor)
    | map({
        monitor: .[0].monitor,
        fs: (any(.[]; (.is_minimized | not) and (
          .is_fullscreen
          or (
            ($mres[.monitor].w // -1) == .width
            and ($mres[.monitor].h // -2) == .height
          )
        )))
      })
    | .[] | select(.monitor as $m | $wl | index($m))
    | [.monitor, .fs] | @tsv
  ')
done
