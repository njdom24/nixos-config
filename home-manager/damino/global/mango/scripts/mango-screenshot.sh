#!/usr/bin/env bash

mode="$1"
SCREENSHOT_DIR="$XDG_RUNTIME_DIR/screenshots"
mkdir -p "$SCREENSHOT_DIR"
timestamp=$(date +%s)
tmpfile="$SCREENSHOT_DIR/$timestamp.png"

# Store to clean up headless outputs on exit
HEADLESS_OUTPUTS=()
trap clear_headless_mode EXIT

set_headless_mode() {
  local display="$1"
  read -r X Y WIDTH HEIGHT SCALE REFRESH <<<"$(
  wlr-randr --json |
    jq -r --arg out "$display" '
    .[]
    | select(.name == $out)
    | . as $monitor
    | ($monitor.modes[] | select(.current)) as $mode
    | "\($monitor.position.x // 0) \($monitor.position.y // 0) \($mode.width) \($mode.height) \($monitor.scale) \($mode.refresh)"
    '
  )"

  echo "Creating headless output" >&2

  # Record where the real outputs are before adding the headless output
  local real_positions
  real_positions="$(output_positions)"

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
  HEADLESS_OUTPUTS+=("$HEADLESS")

  noctalia msg bar-hide "$HEADLESS" 2> /dev/null
  sleep 0.2

  wlr-randr \
    --output "$HEADLESS" \
    --pos "$X,$Y" \
    --scale "$SCALE" \
    --custom-mode "$WIDTH"x"$HEIGHT"@"$REFRESH"Hz

  # Protect against reflowing outputs that were moved by the new headless output
  local restore=() name pos
  while read -r name pos; do
    [[ -z "$name" ]] && continue
    if ! grep -qx "$name $pos" <<<"$(output_positions)"; then
      restore+=(--output "$name" --pos "$pos")
    fi
  done <<<"$real_positions"

  if (( ${#restore[@]} )); then
    echo "Restoring reflowed outputs: ${restore[*]}" >&2
    wlr-randr "${restore[@]}"
  fi
}

# Prints "NAME X,Y" for every enabled non-headless output.
output_positions() {
  wlr-randr --json | jq -r '
    .[]
    | select(.enabled and (.name | startswith("HEADLESS-") | not))
    | "\(.name) \(.position.x),\(.position.y)"
  '
}

clear_headless_mode() {
  (( ${#HEADLESS_OUTPUTS[@]} )) || return 0
  local out
  for out in "${HEADLESS_OUTPUTS[@]}"; do
    wlr-randr --output "$out" --off 2> /dev/null
  done
  HEADLESS_OUTPUTS=()
  headless_count=$(mmsg get all-monitors | jq '
    [
      .monitors[]
      | select(.name | startswith("HEADLESS-"))
      | select(.width > 0 and .height > 0)
    ]
    | length
  ')
  if [[ "$headless_count" -eq 0 ]]; then
    mmsg dispatch destroy_all_virtual_output
  fi
}

# Prefer overlapping HEADLESS outputs for HDR tonemapping
case "$mode" in
  focused)
    output=$(mmsg get all-monitors | jq -r '
      .monitors[]
      | select(.active == true)
      | .name
    ')
    set_headless_mode "$output"

    grim -o "$HEADLESS" "$tmpfile"
    ;;
  select|selector)
    REGION=$(slurp) || exit 1
    read XY WH <<<"$REGION"
    X=${XY%,*}      # before comma
    Y=${XY#*,}      # after comma
    W=${WH%x*}      # before x
    H=${WH#*x}      # after x

    # Get all real outputs that intersect the region
    mapfile -t OUTPUTS < <(mmsg get all-monitors | jq -r \
      --argjson x "$X" \
      --argjson y "$Y" \
      --argjson w "$W" \
      --argjson h "$H" '
      .monitors[]
      | select(.width > 0 and .height > 0)
      | select(.name | startswith("HEADLESS-") | not)
      | select(
        (.x + .width  > $x) and
        ($x + $w > .x) and
        (.y + .height > $y) and
        ($y + $h > .y)
        )
      | .name
    ')

    # Should be good to clean out old screenshot
    rm -f "$SCREENSHOT_DIR/"*
    wl-copy ""

    # Overlap every intersecting output with its own headless output
    for out in "${OUTPUTS[@]}"; do
      set_headless_mode "$out"
    done
    grim -g "$REGION" "$tmpfile"
    ;;
  *)
    echo "Usage: $0 {focused|select}" >&2
    exit 1
    ;;
esac

if [[ -s "$tmpfile" ]]; then
  # Compression can take a while. Put current image in clipboard for immediate pasting
  wl-copy --type text/uri-list <<< "file://$tmpfile"

  clear_headless_mode

  notify-send -a "Screenshot" -i "$tmpfile" "Screenshot taken"

  # Compress to WebP for pasting in chat apps
  newfile="$SCREENSHOT_DIR/$timestamp.webp"
  magick "$tmpfile" \
  -define webp:lossless=true \
  "$newfile"

  wl-copy --type text/uri-list <<< "file://$newfile"
fi
