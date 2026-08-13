#!/usr/bin/env bash

dir="${1:-}"
case "$dir" in
  up|down|left|right) ;;
  *) echo "usage: $0 {up|down|left|right}" >&2; exit 1 ;;
esac

STEP=100

is_floating="$(mmsg get focusing-client | jq -r '.is_floating')"

if [[ "$is_floating" != "true" ]]; then
  exec ~/.config/mango/mango-exchange-or-move.sh "$dir"
fi

case "$dir" in
  up)    dx=0;       dy=-"$STEP" ;;
  down)  dx=0;       dy="$STEP"  ;;
  left)  dx=-"$STEP"; dy=0       ;;
  right) dx="$STEP";  dy=0       ;;
esac

mmsg dispatch "movewin,$(printf '%+d' "$dx"),$(printf '%+d' "$dy")"
