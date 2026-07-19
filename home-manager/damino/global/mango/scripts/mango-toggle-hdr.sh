#!/usr/bin/env bash

set -euo pipefail

CONF=~/.config/mango/monitors.conf

usage() {
    echo "Usage: $0 [output] [on|off]" >&2
    exit 1
}

is_state_word() {
  case "${1,,}" in
    on|off) return 0 ;;
    *) return 1 ;;
  esac
}

OUTPUT=""
STATE_WORD=""

case "$#" in
  0)
    ;;
  1)
    if is_state_word "$1"; then
      STATE_WORD="${1,,}"
    else
      OUTPUT="$1"
    fi
    ;;
  2)
    OUTPUT="$1"
    STATE_WORD="$2"
    is_state_word "$STATE_WORD" || { echo "Error: second argument must be 'on' or 'off'" >&2; usage; }
    STATE_WORD="${STATE_WORD,,}"
    ;;
  *)
    usage
    ;;
esac

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$(mmsg get all-monitors | jq -r '.monitors[] | select(.active == true) | .name')"
    if [[ -z "$OUTPUT" || "$OUTPUT" == "null" ]]; then
      echo "Error: could not determine the focused monitor from mmsg" >&2
      exit 1
    fi
    echo "No output given, targeting focused monitor: $OUTPUT"
fi

# Snapshot the current outputs to ensure the config is up-to-date before editing it
~/.config/mango/mango-snapshot-outputs.sh

[[ -f "$CONF" ]] || { echo "Error: $CONF not found." >&2; exit 1; }

SEARCH="name:^${OUTPUT}\$,"
MATCH_LINE="$(grep -Fn -- "$SEARCH" "$CONF" | head -n1 | cut -d: -f1)"
LINE_CONTENT="$(sed -n "${MATCH_LINE}p" "$CONF")"

CURRENT_STATE=""
if [[ "$LINE_CONTENT" == *"hdr:0"* ]]; then
  CURRENT_STATE=0
elif [[ "$LINE_CONTENT" == *"hdr:1"* ]]; then
  CURRENT_STATE=1
fi

if [[ -z "$MATCH_LINE" ]]; then
  echo "Error: no monitorrule found for output '$OUTPUT' in $CONF" >&2
  echo "Available outputs in config:" >&2
  grep -oP '(?<=name:\^)[^$]+(?=\$,)' "$CONF" >&2 || true
  exit 1
fi

if [[ -n "$STATE_WORD" ]]; then
  # Forced state, regardless of current value.
  [[ "$STATE_WORD" == "on" ]] && NEW_STATE=1 || NEW_STATE=0
else
  is_hdr=$(mmsg get monitor "$OUTPUT" | jq -r '.is_hdr')
  # No state given: toggle.
  if [[ "$is_hdr" == "true" ]]; then
    NEW_STATE=0
  else
    NEW_STATE=1
  fi
fi

if [[ "$LINE_CONTENT" != *"hdr:"* ]]; then
  # No hdr field present on this line yet - add one.
  sed -i "${MATCH_LINE}s/\$/,hdr:${NEW_STATE}/" "$CONF"
elif [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
  sed -i "${MATCH_LINE}s/hdr:${CURRENT_STATE}/hdr:${NEW_STATE}/" "$CONF"
fi
# else: already at the requested/forced state, nothing to edit - still reload below.

echo "HDR for '$OUTPUT' -> hdr:${NEW_STATE}"

mmsg dispatch reload_config
