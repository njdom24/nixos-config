#!/usr/bin/env bash
# Enable adaptive sync on the given outputs while they show a fullscreen
# (or output-sized) window. Requires: mmsg, wlr-randr, jq

set -uo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <monitor> [monitor...]" >&2
  exit 1
fi

LOCKFILE="${XDG_RUNTIME_DIR}/mango_vrr_lock"
rm -f "$LOCKFILE"
whitelist_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)

# reconcile <clients-json> <settled: true|false>
# Compares desired state against Mango's is_vrr (the real state; wlr-randr
# only shows what was last requested). Disables only when settled, since
# refocusing briefly reports no fullscreen window.
reconcile() {
  [[ -e "$LOCKFILE" ]] && return

  local monitors outputs
  monitors=$(mmsg get all-monitors) || return
  outputs=$(wlr-randr --json)       || return

  jq -nr --argjson wl "$whitelist_json" --argjson settled "$2" \
         --argjson c "$1" --argjson m "$monitors" --argjson o "$outputs" '
    ($m.monitors | map(select(.name != null) | {(.name): .}) | add // {}) as $mons
    | ($o | map(select(.enabled and .adaptive_sync != null) | {(.name): .adaptive_sync})
       | add // {}) as $req
    | $wl[] as $n
    | select(($req | has($n)) and ($mons | has($n)))    # off or no VRR support: skip
    | ([ $c.clients[]
         | select(.monitor == $n and (.is_minimized | not))
         | .is_fullscreen
           or (.width == $mons[$n].width and .height == $mons[$n].height)
       ] | any) as $want
    | select($want != ($mons[$n].is_vrr // false))
    | select($want or $settled)
    | [$n, $want, $req[$n]] | @tsv
  ' | while IFS=$'\t' read -r n want req; do
    if [[ "$want" == "true" ]]; then
      echo "[$n] fullscreen — enabling adaptive sync"
      # If VRR is already requested on, a plain enable is a no-op; toggle it.
      [[ "$req" == "true" ]] && wlr-randr --output "$n" --adaptive-sync disabled
      wlr-randr --output "$n" --adaptive-sync enabled
    else
      echo "[$n] no fullscreen — disabling adaptive sync"
      wlr-randr --output "$n" --adaptive-sync disabled
    fi
  done
}

clients='{"clients":[]}'
pending=false

while :; do
  IFS= read -r -t 1 line
  rc=$?
  if (( rc == 0 )); then
    # New event: enable right away if needed, check disables once quiet
    clients=$line
    reconcile "$clients" false
    pending=true
  elif (( rc > 128 )); then
    # 1s with no events: run the full check once, then sit idle
    if [[ "$pending" == "true" ]]; then
      reconcile "$clients" true
      pending=false
    fi
  else
    echo "mmsg watch exited" >&2
    exit 1
  fi
done < <(mmsg watch all-clients)
