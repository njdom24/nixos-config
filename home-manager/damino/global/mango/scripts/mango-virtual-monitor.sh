#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <output>"
  exit 1
fi

OUTPUT="$1"

# Verify the source monitor exists.
mmsg get all-monitors | jq -e --arg out "$OUTPUT" \
  '.monitors[] | select(.name == $out)' >/dev/null ||
{
  echo "Error: monitor '$OUTPUT' not found."
  exit 1
}

# Record existing headless outputs.
before="$(
  wlr-randr | awk '/^HEADLESS-/ { print $1 }'
)"

# Create a new virtual output.
mmsg dispatch create_virtual_output

# Find the newly-created headless output.
HEADLESS=""
for _ in {1..20}; do
  after="$(
    wlr-randr | awk '/^HEADLESS-/ { print $1 }'
  )"

  HEADLESS="$(
    comm -13 \
      <(printf '%s\n' "$before" | sort) \
      <(printf '%s\n' "$after" | sort) \
      | head -n1
  )"

  [[ -n "$HEADLESS" ]] && break
  sleep 0.1
done

if [[ -z "$HEADLESS" ]]; then
  echo "Failed to determine the new virtual output."
  exit 1
fi

(sleep 1 && noctalia msg bar-hide "$HEADLESS" 2> /dev/null) &

read -r X Y WIDTH HEIGHT SCALE REFRESH <<<"$(
  wlr-randr --json |
    jq -r --arg out "$OUTPUT" '
      .[]
      | select(.name == $out)
      | . as $monitor
      | ($monitor.modes[] | select(.current)) as $mode
      | "\($monitor.position.x // 0) \($monitor.position.y // 0) \($mode.width) \($mode.height) \($monitor.scale) \($mode.refresh)"
    '
)"

echo "$WIDTH x $HEIGHT @ $REFRESH Hz @ $SCALE scale, positioned at ($X,$Y) on $OUTPUT"
exit 0
wlr-randr \
  --output "$HEADLESS" \
  --pos "$X,$Y" \
  --scale "$SCALE" \
  --custom-mode "${WIDTH}x${HEIGHT}@${REFRESH}Hz"

echo "Configured $HEADLESS to match $OUTPUT."