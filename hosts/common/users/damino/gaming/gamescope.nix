# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let
  addIfMissing = existing: p: if builtins.any (x: x == p) existing then [] else [p];

  get_vrr = pkgs.writeShellScript "get_vrr.sh" ''
    # Account for nested case
    desktop="$XDG_CURRENT_DESKTOP"
    display="$DISPLAY"
    wdisplay="$WAYLAND_DISPLAY"
    session="$XDG_SESSION_TYPE"

    if [[ "$XDG_CURRENT_DESKTOP" = "gamescope" ]]; then
      XDG_CURRENT_DESKTOP="$_GSC_PARENT_DESKTOP"
      DISPLAY="$_GSC_PARENT_DISPLAY"
      WAYLAND_DISPLAY="$_GSC_PARENT_WAYLAND_DISPLAY"
      XDG_SESSION_TYPE="$_GSC_PARENT_SESSION_TYPE"
    fi

    if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      vrr_status=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .adaptive_sync_status')
      echo "$vrr_status"
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      # Toggling VRR doesn't apply until toggling fullscreen. VFR applies immediately avoids touching monitor configs, so we use it
      vfr_status=$(LD_LIBRARY_PATH="" hyprctl -j getoption misc:vfr | ${pkgs.jq}/bin/jq '.int')
      echo "$vfr_status"
    elif [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      # TODO
      echo "0"
    else
      echo "0"
    fi

    XDG_CURRENT_DESKTOP="$desktop"
    DISPLAY="$display"
    WAYLAND_DISPLAY="$wdisplay"
    XDG_SESSION_TYPE="$session"
  '';

  set_vrr = pkgs.writeShellScript "set_vrr.sh" ''
    vrr_mode="$1"

    # Account for nested case
    desktop="$XDG_CURRENT_DESKTOP"
    display="$DISPLAY"
    wdisplay="$WAYLAND_DISPLAY"
    session="$XDG_SESSION_TYPE"

    if [[ "$XDG_CURRENT_DESKTOP" = "gamescope" ]]; then
      XDG_CURRENT_DESKTOP="$_GSC_PARENT_DESKTOP"
      DISPLAY="$_GSC_PARENT_DISPLAY"
      WAYLAND_DISPLAY="$_GSC_PARENT_WAYLAND_DISPLAY"
      XDG_SESSION_TYPE="$_GSC_PARENT_SESSION_TYPE"
    fi

    if [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      monitor=$(LD_LIBRARY_PATH="" hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.focused==true).name")
      LD_LIBRARY_PATH="" hyprctl keyword "misc:vfr" "$vrr_mode"
      LD_LIBRARY_PATH="" hyprctl dispatch fullscreen
      LD_LIBRARY_PATH="" hyprctl dispatch fullscreen
      (
        sleep 1
        LD_LIBRARY_PATH="" hyprctl keyword "monitorv2[$monitor]:vrr" "$vrr_mode"
        LD_LIBRARY_PATH="" hyprctl dispatch fullscreen
        LD_LIBRARY_PATH="" hyprctl dispatch fullscreen
      ) &
    elif [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      focused_display=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
      swaymsg output $focused_display adaptive_sync "$vrr_mode"
    fi

    XDG_CURRENT_DESKTOP="$desktop"
    DISPLAY="$display"
    WAYLAND_DISPLAY="$wdisplay"
    XDG_SESSION_TYPE="$session"
  '';

  novrr = pkgs.writeShellScriptBin "novrr" ''
    # Communicate with sway VRR fullscreen script to prevent it from overriding
    if [[ -v SWAYSOCK ]]; then
      touch "$XDG_RUNTIME_DIR"/sway_vrr_lock
    fi

    vrr_start="$(${get_vrr})"
    ${set_vrr} 0

    cleanup() {
      local ec=$?
      ${set_vrr} $vrr_start
      if [[ -v SWAYSOCK ]] && ! ${pkgs.procps}/bin/pgrep -f "novrr" | ${pkgs.gnugrep}/bin/grep -v $$ >/dev/null; then
        rm "$XDG_RUNTIME_DIR"/sway_vrr_lock
      fi
      exit "$ec"
    }

    trap cleanup EXIT INT TERM HUP QUIT

    # Drop leading '--' if present
    if [[ "''${1-}" == "--" ]]; then
      shift
    fi
    # "''$()"

    "$@"
  '';

  # Resolution & refresh detection
  get_display_mode = pkgs.writeShellScript "get-display-mode.sh" ''
    # Sway 1.11 sets this OOTB now
    if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '
        .[] | select(.focused) | "\(.current_mode.width) \(.current_mode.height) \(.current_mode.refresh / 1000)"
      '
    elif [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
      read width height refresh <<< $(LD_LIBRARY_PATH="" hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '
        .[] 
        | select(.focused == true) 
        | [.width, .height, (.refreshRate | floor)] 
        | @tsv
      ')
      echo "$width $height $refresh"
    elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
      read width height refresh < <(
        ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j | ${pkgs.jq}/bin/jq -r '
          (.outputs | map(select(.enabled == true)) | sort_by(.priority))[0] as $out |
          ($out.currentModeId) as $curId |
          ($out.modes[] | select(.id == $curId)) |
          "\(.size.width) \(.size.height) \(.refreshRate)"
        '
      )
      echo "$width $height $refresh"
      
    # XWayland / X11 fallback (nested gamescope)
    elif ${pkgs.xorg.xrandr}/bin/xrandr >/dev/null 2>&1; then
      # Get primary or first
      primary=$(${pkgs.xorg.xrandr}/bin/xrandr | ${pkgs.gawk}/bin/awk '/ connected/ {if(/ primary /){print $1;exit}else if(!f)f=$1} END{print f}')

      read resolution refresh_raw < <(
        ${pkgs.xorg.xrandr}/bin/xrandr | ${pkgs.gawk}/bin/awk -v primary="$primary" '
          $1 == primary {in_primary=1; next}
          in_primary && /\*/ {
            print $1, $2
            exit
          }
        '
      )

      # Parse width and height from resolution (e.g., 2560x1440)
      width="''${resolution%x*}"
      height="''${resolution#*x}"
      
      # Clean refresh rate (e.g., remove *+)
      refresh="''${refresh_raw//[^0-9.]}"

      # echo "''$()"
      echo "$width $height $refresh"
    fi
  '';

  # LSFG helper (place after FPS limits to be smart about them)
  # Only activate above a set refresh rate
  lsfg-min = pkgs.writeShellScriptBin "lsfg-min" ''
    #!/usr/bin/env bash
    set -eo pipefail
    TEST="$2"
    
    # Early exit if explicitly disabled
    if [[ "$ENABLE_LSFG" = "0" || "$LSFG_LEGACY" = "0" ]]; then
      exec "$@"
    fi
    
    if [ $# -lt 2 ]; then
      echo "Usage: $(basename "$0") <min_refresh_rate> <command> [args...]" >&2
      exit 1
    fi
    
    min="$1"
    shift

    if mode="$(${get_display_mode})"; then
      read width height refresh <<< "$mode"
    else
      width=1920 height=1080 refresh=60
    fi

    refresh=$(echo $refresh | ${pkgs.num-utils}/bin/round)
    
    if [ "$refresh" -ge "$min" ]; then
      export LSFG_LEGACY=1
      export LSFG_MULTIPLIER=2

      flow_scale=$(echo "scale=2; 1080 / $height" | ${pkgs.bc}/bin/bc)
      export LSFG_FLOW_SCALE=$(echo "$flow_scale" | ${pkgs.gnused}/bin/sed -E 's/^(-?)\./\10./')
      echo "Using LSFG flow scale: $LSFG_FLOW_SCALE"

      # Default to performance mode
      export LSFG_PERFORMANCE_MODE="''${LSFG_PERFORMANCE_MODE:-1}"
      # "''$()

      # FPS limiter multipliers disabled -- Current releases seem to be applied after limiters now

      # --- MANGOHUD_FPS_LIMIT ---
      if [[ -n "$MANGOHUD_FPS_LIMIT" && false ]]; then
        new_limit=$((MANGOHUD_FPS_LIMIT * 2))
        export MANGOHUD_FPS_LIMIT="$new_limit"
        echo "New MANGOHUD_FPS_LIMIT: $MANGOHUD_FPS_LIMIT"
      fi

      # --- MANGOHUD_CONFIG ---
      if [[ -n "$MANGOHUD_CONFIG" && false ]]; then
        if [[ "$MANGOHUD_CONFIG" =~ fps_limit=([0-9]+) ]]; then
          last_fps_limit=""
          IFS=',' read -ra cfg_parts <<< "$MANGOHUD_CONFIG"
          for part in "''${cfg_parts[@]}"; do
            if [[ "$part" =~ ^fps_limit=([0-9]+)$ ]]; then
              last_fps_limit="''${BASH_REMATCH[1]}"
            fi
          done

          new_limit=$((last_fps_limit * 2))
    
          # Remove existing fps_limit, normalize commas
          cleaned=$(echo "$MANGOHUD_CONFIG" | ${pkgs.gnused}/bin/sed -E 's/(^|,)fps_limit=[0-9]+//g' | ${pkgs.gnused}/bin/sed -E 's/^,+|,+$//g' | ${pkgs.gnused}/bin/sed -E 's/,+/,/g')
          if [ -z "$cleaned" ]; then
            export MANGOHUD_CONFIG="fps_limit=$new_limit"
          else
            export MANGOHUD_CONFIG="$cleaned,fps_limit=$new_limit"
          fi

          echo "New MANGOHUD_CONFIG: $MANGOHUD_CONFIG"
          #echo "LSFG_HDR: $LSFG_HDR"
          #echo "LSFG_HDR: $LSFG_HDR_MODE" # Also renamed to this
        fi
      fi
    else
      echo "Refresh rate $refresh below minimum. Not enabling LSFG"
    fi

    exec ${novrr}/bin/novrr "$@"
  '';

  # Gamescope helper to auto-fill mode, HDR, update settings
  gsc = pkgs.writeShellScriptBin "gsc" ''
    #!/usr/bin/env bash

    export _GSC_PARENT_DESKTOP="''${_GSC_PARENT_DESKTOP:-$XDG_CURRENT_DESKTOP}"
    export _GSC_PARENT_DISPLAY="''${_GSC_PARENT_DISPLAY:-$DISPLAY}"
    export _GSC_PARENT_WAYLAND_DISPLAY="''${_GSC_PARENT_WAYLAND_DISPLAY:-$WAYLAND_DISPLAY}"
    export _GSC_PARENT_SESSION_TYPE="''${_GSC_PARENT_SESSION_TYPE:-$XDG_SESSION_TYPE}"

    strip_ansi() {
      # Removes ANSI escape sequences
      ${pkgs.gnused}/bin/sed -r "s/\x1B\[[0-9;]*[mK]//g"
    }

    get_hdr() {
      # Account for nested case
      desktop="$XDG_CURRENT_DESKTOP"
      display="$DISPLAY"
      wdisplay="$WAYLAND_DISPLAY"
      session="$XDG_SESSION_TYPE"

      XDG_CURRENT_DESKTOP="$_GSC_PARENT_DESKTOP"
      DISPLAY="$_GSC_PARENT_DISPLAY"
      WAYLAND_DISPLAY="$_GSC_PARENT_WAYLAND_DISPLAY"
      XDG_SESSION_TYPE="$_GSC_PARENT_SESSION_TYPE"

      get_edid_luminance() {
        local monitor="$1"
        local edid_path=""

        # Find EDID dynamically under card*
        for card in /sys/class/drm/card*; do
          candidate="$card-$monitor/edid"
          if [ -f "$candidate" ]; then
            edid_path="$candidate"
            break
          fi
        done

        if [ -z "$edid_path" ]; then
          echo "0 0 0"
          return 0
        fi

        local edid_output
        edid_decoded=$(${pkgs.edid-decode}/bin/edid-decode < "$edid_path")

        if ! echo "$edid_decoded" | ${pkgs.gnugrep}/bin/grep -q "HDR Static Metadata Data Block"; then
          echo "0 0 0"
          return 0
        fi

        # Function to extract a luminance value given the line label
        extract_lum() {
          local label="$1"
          echo "$edid_decoded" \
            | ${pkgs.gnugrep}/bin/grep -A10 "HDR Static Metadata Data Block" \
            | ${pkgs.gnugrep}/bin/grep "$label" \
            | ${pkgs.gnused}/bin/sed -E 's/.*\(([0-9.]+) cd\/m\^2\).*/\1/' \
            | ${pkgs.gnused}/bin/sed -E 's/\..*//'
        }

        local max_lum avg_lum min_lum
        max_lum=$(extract_lum "Desired content max luminance")
        avg_lum=$(extract_lum "Desired content max frame-average luminance")
        min_lum=$(extract_lum "Desired content min luminance")

        # "''$()" 
        # Fallback if luminance fields are missing (Common with TVs)
        max_lum=''${max_lum:-1000}
        avg_lum=''${avg_lum:-1000}
        min_lum=''${min_lum:-0}
        # "''$()"

        echo "$max_lum $avg_lum $min_lum"
      }

      if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
        # Use local swaymsg in case of using a different Sway package
        focused_display="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')"
        # hdr_support="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$focused_display\") | .features.hdr")"
        hdr_enabled="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$focused_display\") | .hdr")"
        if [[ "$hdr_enabled" == "true" ]]; then
          read edid_max edid_avg edid_min <<< "$(get_edid_luminance "$focused_display")"
          if [[ "$edid_max" != "0" ]]; then
            echo "1 203 $edid_max"
          else
            echo "0 0 0"
          fi
        else
          echo "0 0 0"
        fi
      elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
        focused_display=$(LD_LIBRARY_PATH="" hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
        conf="$HOME/.config/hypr/displays.conf"

        # TODO: Replace with more reliable check after https://github.com/hyprwm/Hyprland/pull/12019
        if [[ ! -f "$conf" ]]; then
          read edid_max edid_avg edid_min <<< "$(get_edid_luminance "$focused_display")"
          if [[ "$edid_max" != "0" ]]; then
            echo "1 203 $edid_max"
          else
            echo "0 0 0"
          fi
          return 0
        fi

        block=$(${pkgs.gawk}/bin/awk -v mon="$focused_display" '
          /^[[:space:]]*monitorv2[[:space:]]*{/ { inblock=1; block="" }
          inblock {
            block = block $0 "\n"
            if ($0 ~ /^[[:space:]]*}/) {
              if (block ~ ("output[[:space:]]*=[[:space:]]*" mon)) {
                print block
                exit
              }
              inblock=0
            }
          }
        ' "$conf")

        hdr_support=$(${pkgs.gawk}/bin/awk -F'=' '/^[[:space:]]*supports_hdr[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$block")
        cm=$(LD_LIBRARY_PATH="" hyprctl monitors -j | ${pkgs.jq}/bin/jq -r --arg o "$focused_display" '.[] | select(.name == $o) | .colorManagementPreset')
        sdr_max=$(LD_LIBRARY_PATH="" hyprctl monitors -j | ${pkgs.jq}/bin/jq -r --arg o "$focused_display" '.[] | select(.name == $o) | .sdrMaxLuminance')
        max_lum=$(${pkgs.gawk}/bin/awk -F'=' '/^[[:space:]]*max_luminance[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$block")
     
        #if [[ "$hdr_support" != "0" ]] && [[ "$hdr_support" = "1" || "$cm" = "hdr" || "$cm" = "hdredid" || "$max_lum" -gt 400 ]]; then
        if [[ "$hdr_support" != "0" ]] && [[ "$cm" = "hdr" || "$cm" = "hdredid" || "$max_lum" -gt 400 || "$sdr_max" -gt 80 ]]; then
          echo "1 $sdr_max $max_lum"
        else
          echo "0 0 0"
        fi
      elif [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
        json=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j)
        enabled=$(${pkgs.jq}/bin/jq -r '
          .outputs
          | map(select(.enabled == true and .priority == 1))
          | .[0].hdr
        ' <<< "$json")
        if [[ "$enabled" != "true" ]]; then
          echo "0 0 0"
        else
          # Get paper white
          paper_white=$(${pkgs.jq}/bin/jq -r '
            .outputs
            | map(select(.enabled == true and .priority == 1))
            | .[0]["sdr-brightness"]
          ' <<< "$json")
          
          # Get peak brightness (Currently not exposed to JSON)
          output=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o | strip_ansi)
    
          block=$(${pkgs.gawk}/bin/awk '
            BEGIN { RS="Output: "; FS="\n" }
            $0 ~ /enabled/ && $0 ~ /priority 1/ {
              print $0
              exit
            }
          ' <<< "$output")
    
          line=$(${pkgs.gnugrep}/bin/grep -m1 "Peak brightness:" <<< "$block")
          peak=$(echo "$line" | ${pkgs.gnugrep}/bin/grep -o '[0-9]\+' | ${pkgs.coreutils}/bin/head -n1)
    
          echo "1 $paper_white ''${peak:-1000}"
          # "''$()"
        fi
      else
        echo "0 0 0"
      fi

      XDG_CURRENT_DESKTOP="$desktop"
      DISPLAY="$display"
      WAYLAND_DISPLAY="$wdisplay"
      XDG_SESSION_TYPE="$session"
    }

    if mode="$(${get_display_mode})"; then
      read width height refresh <<< "$mode"
    else
      width=1920 height=1080 refresh=60
    fi
    refresh=$(echo $refresh | ${pkgs.num-utils}/bin/round)

    if [[ -v MANGOHUD_FPS_LIMIT ]]; then
      fps_limit="$MANGOHUD_FPS_LIMIT"
    else
      fps_limit=""
    fi
    refresh_rate=""
    steam_mode=0

    #if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
    #  hypr-toggle-hdr off
    #fi

    # Use a loop to walk through the args
    extra_flags=()
    to_run=()
    i=0
    while [ $i -lt $# ]; do
      arg="''${@:$((i+1)):1}"
      echo "''$()"
      echo "Looping arg $arg"
    
      # Check for MANGOHUD_CONFIG
      if [[ "$arg" == MANGOHUD_CONFIG=* ]]; then
        config="''${arg#MANGOHUD_CONFIG=}"
        config="''${config#\"}"
        config="''${config%\"}"
    
        IFS=',' read -ra settings <<< "$config"
        for setting in "''${settings[@]}"; do
          if [[ "$setting" == fps_limit=* ]]; then
            fps_limit="''${setting#fps_limit=}"
            break
          fi
        done

      elif [[ "$arg" == MANGOHUD_FPS_LIMIT=* ]]; then
        fps_limit="''${arg#*=}"
        echo '''
      # Found to be unnecessary / potentially worse
      #elif [[ ( "$arg" == "ENABLE_LSFG=1" || "$arg" == "LSFG_LEGACY=1" || "$arg" == "lsfg-min" ) && -v hdr_enabled ]]; then
      #  export LSFG_HDR="$hdr_enabled"
      fi

      # Check for gamescope args
      if [[ -v scope_vars_done ]]; then
        to_run+=("$arg")
      else
        # Check for -r <value>
        if [[ "$arg" == "-r" ]]; then
          next="''${@:$((i+2)):1}"
          if [[ -n "$next" ]]; then
            refresh_rate="$next"
          fi
          i=$((i+2)) # skip the next one too
          continue
        fi

        if [[ "$arg" == "--steam" || "$arg" == "-e" ]]; then
          steam_mode=1
        fi

        if [[ "$arg" == "--hdr-enabled" ]]; then
          if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
            hypr-toggle-hdr on
          fi
        fi

        if [[ "$arg" == "--" ]]; then
          scope_vars_done=1
        else
          extra_flags+=("$arg")
        fi
      fi

      i=$((i+1))
    done
    # "''$()"

    if [ -v scope_vars_done ]; then
      echo "Commands to run: $to_run"
      for arg in "''${to_run[@]}"; do
        printf "[%s] " "$arg"
      done
      echo "''$()"
    else
      echo "gsc requires explicit arg separation with '--'"
      exit 1
    fi

    read hdr_enabled hdr_paper_white hdr_peak <<< "$(get_hdr)"

    # Try to configure RenoDX HDR ReShade automatically
    if [[ -v RENODX_HDR && "$RENODX_HDR" == "1" ]]; then
      reshade_file="$(${pkgs.coreutils}/bin/timeout 5 ${pkgs.findutils}/bin/find "$PWD" -type f -name 'ReShade.ini' | ${pkgs.coreutils}/bin/head -n 1)"

      if [[ -n "$reshade_file" ]]; then
        reshade_dir="$(dirname "$reshade_file")"
        # Find matching .addon64 file containing 'renodx'
        addon_file="$(${pkgs.findutils}/bin/find "$reshade_dir" -maxdepth 1 -type f -name '*.addon64' -printf '%f\n' | ${pkgs.gnugrep}/bin/grep renodx | head -n1)"
        addon_id="RenoDX@$addon_file"

        if [[ "$hdr_enabled" == "1" ]]; then
          addon_file_bak="$(${pkgs.findutils}/bin/find "$reshade_dir" -maxdepth 1 -type f -name '*.addon64.bak' -printf '%f\n' | ${pkgs.gnugrep}/bin/grep renodx | head -n1)"
          # Enable: move .bak back to .addon64 if needed
          if [[ -n "$addon_file_bak" ]]; then
            mv -f "$addon_file_bak" "''${addon_file_bak%.bak}"
            # "''$()"
          fi
        fi

        # Try to enable/disable automatically
        if ${pkgs.gnugrep}/bin/grep -q '^\[ADDON\]' "$reshade_file"; then
          # Read current DisabledAddons value from [ADDON] section
          current=$(${pkgs.gawk}/bin/awk -F= '/^\[ADDON\]/{f=1} f && /^DisabledAddons=/{print substr($0, index($0,$2)) ; exit}' "$reshade_file" | ${pkgs.coreutils}/bin/tr -d '\r\n' | ${pkgs.gnused}/bin/sed 's/^,*//; s/,*$//; s/ //g')
          # Helper function
          contains() {
            [[ ",$1," == *",$2,"* ]]
          }

          if [[ "$hdr_enabled" == "0" ]]; then
            # Append addon_id if missing
            if ! contains "$current" "$addon_id"; then
              if [[ -z "$current" ]]; then
                new_disabled_addons="$addon_id"
              else
                new_disabled_addons="$current,$addon_id"
              fi
            fi
          elif [[ "$hdr_enabled" == "1" ]]; then
            # Remove addon_id if present
            if contains "$current" "$addon_id"; then
              # Filter the addon_id from the list
              IFS=',' read -ra arr <<< "$current"
              new_arr=()
              for addon in "''${arr[@]}"; do
                if [[ "$addon" != "$addon_id" && -n "$addon" ]]; then
                  new_arr+=("$addon")
                fi
              done
              new_disabled_addons=$(IFS=, ; echo "''${new_arr[*]}")
            fi
          fi

          if [[ -v new_disabled_addons ]]; then
            temp_file="$(${pkgs.mktemp}/bin/mktemp)"

            # Update the INI file DisabledAddons= line inside [ADDON]
            ${pkgs.gawk}/bin/awk -v new="$new_disabled_addons" '
            BEGIN{in_addon=0}
             /^\[ADDON\]/ {in_addon=1; print; next}
             /^\[/ && !/^\[ADDON\]/ {in_addon=0}
             in_addon && /^DisabledAddons=/ {print "DisabledAddons=" new; next}
             {print}
            ' "$reshade_file" > "$temp_file" && mv "$temp_file" "$reshade_file"
          fi
        else
          if [[ "$hdr_enabled" == "0" ]]; then
            # Disable: move .addon64 to .addon64.bak if exists
            if [[ -n "$addon_file" ]]; then
              mv -f "$addon_file" "$addon_file.bak"
            fi
          fi
        fi

        if [[ "$hdr_enabled" == "1" ]]; then
          if [[ "$XDG_CURRENT_DESKTOP" == "KDE" || "$_GSC_PARENT_DESKTOP" == "KDE" ]]; then
            # Scale peak brightness by luminance multiplier from base of 203 nits
            scale=$(echo "scale=4; $hdr_paper_white / 203" | ${pkgs.bc}/bin/bc)
            adjusted_peak=$(echo "$hdr_peak / $scale" | ${pkgs.bc}/bin/bc)
          else
            # Not KDE: don't scale
            adjusted_peak=$hdr_peak
          fi

          # Set peak brightness
          ${pkgs.gnused}/bin/sed -i "s/^ToneMapPeakNits=.*/ToneMapPeakNits=$adjusted_peak/" "$reshade_file"
          ${pkgs.gnused}/bin/sed -i "s/^toneMapPeakNits=.*/toneMapPeakNits=$adjusted_peak/" "$reshade_file"
        fi

      fi
    fi

    # Skip wrapping if we're already inside Gamescope. Execute everything after '--'
    if [ "$XDG_CURRENT_DESKTOP" = "gamescope" ]; then
      while [ "$#" -gt 0 ]; do
        if [ "$1" = "--" ]; then
          shift
          #exec "$@"
          if [[ "$hdr_enabled" == "1" ]]; then
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 1
          fi
          if [[ -n "$refresh_rate" ]]; then
            echo "Setting FPS limit to $refresh_rate"
            ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $refresh_rate
          fi
          export DXVK_HDR="$hdr_enabled"
          "$@"
          #if [[ "$_GSC_PARENT_DESKTOP" == "Hyprland" || "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
          #  hypr-toggle-hdr off
          #fi
          if [[ -n "$refresh_rate" ]]; then
            echo "Re-setting FPS limit from $refresh_rate to $refresh"
            ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $refresh
          fi
          exit 0
        fi
        shift
      done
    
      echo "Error: '--' not found. No command to run." >&2
      exit 1
    else
      if [[ -n "$refresh_rate" ]]; then
        refresh="$refresh_rate"
      fi
    fi

    echo "Limits: $fps_limit,$refresh_rate"

    # Set environment variables
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}='${lib.escapeShellArg v}'") config.programs.gamescope.env)}

    # If MangoHud is enabled, translate to mangoapp
    mangoapp_flag=""
    # Avoid this path for now
    if [[ -v NO_MANGOHUD && "$MANGOHUD" = "1" ]]; then
      mangoapp_flag="--mangoapp"
    fi
    if [[ -v MANGOHUD_CONFIGFILE && -f "$MANGOHUD_CONFIGFILE" ]]; then
      mangohud_path="$MANGOHUD_CONFIGFILE"
    elif [[ -f "/home/$USER/.config/MangoHud/MangoHud.conf" ]]; then
      mangohud_path="/home/$USER/.config/MangoHud/MangoHud.conf"
    fi

    #mangoapp_file="$(${pkgs.mktemp}/bin/mktemp --tmpdir=/home/$USER)" # tmpdir required only for Steam mode since it has unique /tmp (on NixOS?)
    mangohud_file="$(${pkgs.mktemp}/bin/mktemp --tmpdir=/home/$USER)"

    if [[ -v mangohud_path ]]; then
      #${pkgs.coreutils}/bin/cat "$mangohud_path" > "$mangoapp_file" # Copy current config
      ${pkgs.coreutils}/bin/cat "$mangohud_path" > "$mangohud_file" # Copy current config

      # Remove settings that can affect gamescope's frame pacing (Primarily for Steam mode, but won't hurt in general)
      ${pkgs.gnused}/bin/sed -i '/^fps_limit=/d' "$mangohud_file" # Remove FPS limiter
      ${pkgs.gnused}/bin/sed -i '/^fps_limit_method=/d' "$mangohud_file" # Remove FPS limit method
      ${pkgs.gnused}/bin/sed -i "1i fps_limit=$refresh" "$mangohud_file"

      # Force 'late' FPS limiter because 'early' is broken
      if ${pkgs.gnugrep}/bin/grep -q '^fps_limit_method=early' "$mangohud_file"; then
        ${pkgs.gnused}/bin/sed -i 's/^fps_limit_method=early/fps_limit_method=late/' "$mangohud_file"
      elif ! ${pkgs.gnugrep}/bin/grep -q '^fps_limit_method=' "$mangohud_file"; then
        echo 'fps_limit_method=late' >> "$mangohud_file"
      fi

      #if [[ "$steam_mode" == "1" ]]; then
      #  # MangoApp's keybinds don't work in Steam mode
      #  mangoapp_flag=""
      #else
      #  mangoapp_flag="--mangoapp"
      #  MANGOHUD=0
      #fi

      #mangoapp_flag="--mangoapp -- env MANGOHUD_CONFIGFILE=$mangohud_file "
      #echo "$mangoapp_flag $@" > /home/damino/test.log
    fi

    export MANGOHUD_CONFIGFILE="$mangohud_file"

    #if [[ -v MANGOHUD_CONFIG ]]; then
      #export MANGOHUD_CONFIG="fps_limit=$internal_refresh,$MANGOHUD_CONFIG"
    #fi

    echo "Launching gamescope at $width"x"$height@$refresh"
    ld_preload_pass="''${LD_PRELOAD-}"

    # DXVK_HDR=1 should only be needed for Hyprland, but doesn't hurt to do that globally
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
      if [[ "$hdr_enabled" == "1" ]]; then
        extra_flags+=("--hdr-debug-force-support")
      fi
    elif [[ "$XDG_CURRENT_DESKTOP" == "sway" ]]; then
      extra_flags+=("--hdr-debug-force-support")
    fi

    if [[ "$height" -gt 1440 ]]; then
      extra_flags+=("--cursor-scale-height")
      extra_flags+=("1440")
    fi

    # --xwayland-count 2 Causes a limit of 1080p with -steamos3
    if [[ "$steam_mode" == "1" ]]; then
      extra_flags+=("--xwayland-count")
      extra_flags+=("2")
    fi

    # React to gamescope's errors
    set -o pipefail
    while true; do

      if env -u LD_PRELOAD env -u WLR_XWAYLAND ${pkgs.gamescope}/bin/gamescope \
      ${lib.concatMapStringsSep " " (arg: lib.escapeShellArgs (lib.splitString " " arg))
        config.programs.gamescope.args} \
        -r "$refresh" -w "$width" -h "$height" -W "$width" -H "$height" \
        $mangoapp_flag "''${extra_flags[@]}" \
        -- env STEAM_MULTIPLE_XWAYLANDS="$steam_mode" DXVK_HDR="$hdr_enabled" LD_PRELOAD="$ld_preload_pass" "''${to_run[@]}"

      then
        ## } -r "''${rate:-$refresh}" -W "$width" -H "$height" $mangoapp_flag "$@"; then
        break
      elif [[ "$steam_mode" == "0" ]]; then
        break
      else
        code=$?
        if [[ "$code" -eq 143 || "$code" -eq 137 ]]; then
          echo "gamescope exited normally"
          break
        fi
        echo "gamescope exited with code $code, retrying in 1 second..."
        sleep 1
      fi

    done

    #if [[ -v mangoapp_file ]]; then
    #  rm -f "$mangoapp_file"
    #fi
    if [[ -v mangohud_file ]]; then
      rm -f "$mangohud_file"
    fi
  '';

  gsc-watcher = let
    eotfConfig = pkgs.writeText "hdmi_lut" ''
      0 0
      100 50
      160 75
      400 230
      700 270
      800 400
      1000 450
      2000 400
      3000 500
      10000 10000
    '';
  in pkgs.writeShellScriptBin "gsc-watcher" ''
    vrr_pid=""
    toggle_vrr() {
      # Work around Hyprland Auto-HDR modesetting instability with VRR on some displays (Thanks TCL)
      #echo "gsc: VRR mode: $vrr_mode"
      if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" || "$XDG_CURRENT_DESKTOP" == "sway" ]]; then
        if ! ${pkgs.procps}/bin/pgrep -x "novrr" >/dev/null; then
          (${set_vrr} 0 && sleep 10 && ${set_vrr} "1") &
          vrr_pid=$!
        fi
      fi
    }

    hdr_mod_enable() {
      if [[ "$GSC_HDR_MOD" == "1" ]]; then
        if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
          scanout=$(hyprctl getoption render:direct_scanout -j | jq -r '.int')
          hyprctl keyword "render:direct_scanout" "0"
          sleep 1
        fi

        ${pkgs.wlr-hdr-calibrator}/bin/wlr-hdr-calibrator ${eotfConfig} &
        sleep 1

        if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
          hyprctl keyword "render:direct_scanout" "$scanout"
        fi
      fi
    }

    hdr_mod_disable() {
       if [[ "$GSC_HDR_MOD" == "1" ]]; then
         if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
           scanout=$(hyprctl getoption render:direct_scanout -j | jq -r '.int')
           hyprctl keyword "render:direct_scanout" "0"
           sleep 1
         fi

         kill `pgrep -f wlr-hdr-calibrator`
         sleep 1

         if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
           hyprctl keyword "render:direct_scanout" "$scanout"
         fi
       fi
    }

    # Vars to help find screenshot dir
    USER_LOG="$HOME/.steam/steam/logs/connection_log.txt"
    STEAM_USERID=$(${pkgs.gnugrep}/bin/grep -Po '\[U:1:\K[0-9]+' "$USER_LOG" | tail -n1)
    SCREENSHOT_BASE="$HOME/.local/share/Steam/userdata/$STEAM_USERID/760/remote"
    app_id=""
    latest_screenshot=""
    ${pkgs.expect}/bin/unbuffer ${gsc}/bin/gsc "$@" 2>&1 | while IFS= read -r line; do
      echo "$line"

      # Strip ANSI escape codes
      line=$(echo "$line" | ${pkgs.gnused}/bin/sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g')

      if [[ "$line" == "Adding process "*" for gameID "* ]]; then
        #"''$()"
        new_app_id="''${line##*for gameID }"
        if [[ "$app_id" != "$new_app_id" ]]; then
          app_id="$new_app_id"
          screenshot_dir="$SCREENSHOT_BASE/$app_id/screenshots"
          latest_jpg="$(ls -t "$screenshot_dir"/*.jpg 2>/dev/null | head -n1)"
        fi
      elif [[ "$line" == "[gamescope] [Info]  xwm: Screenshot saved to "*".png" ]]; then
        if [[ "$curr_colorspace" == "HDR" ]]; then
          # Brighten tonemapped HDR screenshot because Steam underexposes them
          screenshot_dir="$SCREENSHOT_BASE/$app_id/screenshots"
          echo "Checking screenshot dir for APPID $app_id: $screenshot_dir"

          while true; do
            sleep 1
            latest_jpg="$(ls -t "$screenshot_dir"/*.jpg 2>/dev/null | head -n1)"

            # Check if the newest file changed
            if [[ "$latest_jpg" != "$latest_screenshot" ]]; then
              echo "Brightening HDR screenshot: $latest_jpg"
              #cp "$latest_jpg" "$latest_jpg".orig
              thumbnail="$screenshot_dir/thumbnails/$(basename "$latest_jpg")"
              (
                ${pkgs.imagemagick}/bin/magick "$latest_jpg" -brightness-contrast 8x16 "$latest_jpg"
                ${pkgs.imagemagick}/bin/magick "$thumbnail" -brightness-contrast 8x16 "$thumbnail"
              ) &
              latest_screenshot="$latest_jpg"
              break
            fi
          done
        fi
      elif [[ "$line" == "[Gamescope WSI]"* && "$line" == *"colorspace:"* ]]; then
        if [[ "$line" == *"VK_COLOR_SPACE_HDR10_ST2084_EXT"* \
           || "$line" == *"VK_COLOR_SPACE_EXTENDED_SRGB_LINEAR_EXT"* ]]; then
          if [[ "''${last_colorspace:-}" != "HDR" ]]; then
            echo "gsc: Detected HDR swapchain: $line" >&2
            curr_colorspace="HDR"
            if [[ "$GSC_HDR_MODESET" == "1" ]]; then
              if [[ "$XDG_CURRENT_DESKTOP" == "sway" ]]; then
                if command -v sway-toggle-hdr >/dev/null 2>&1; then
                  sway-toggle-hdr on
                else
                  focused_display=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
                  swaymsg output $focused_display hdr on
                fi
              elif [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
                hypr-toggle-hdr on
              fi
              hdr_mod_enable
            fi
          fi
        elif [[ "$line" == *"VK_COLOR_SPACE_SRGB_NONLINEAR_KHR"* ]]; then
          if [[ "''${last_colorspace:-}" != "SDR" ]]; then
            echo "gsc: Detected SDR swapchain: $line" >&2
            curr_colorspace="SDR"
            if [[ "$GSC_HDR_MODESET" == "1" ]]; then
              if [[ "$XDG_CURRENT_DESKTOP" == "sway" ]]; then
                if command -v sway-toggle-hdr >/dev/null 2>&1; then
                  sway-toggle-hdr off
                else
                  focused_display=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
                  swaymsg output $focused_display hdr off
                fi
              elif [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
                hypr-toggle-hdr off
              fi
              hdr_mod_disable
            fi
          fi
        fi
        if [[ "$curr_colorspace" != "$last_colorspace" ]]; then
          if [[ "$GSC_HDR_MODESET" == "1" ]]; then
            toggle_vrr
          fi
          last_colorspace="$curr_colorspace"
        fi
      # "''$()"
      elif [[ "''${last_colorspace:-}" != "HDR" ]] && [[ "$line" == "Game Recording - game stopped"* || "$line" == "Removing process"*"for gameID"* ]]; then
        # Restore HDR on game exit, or Gamescope will lose HDR capability for next launched game
        if [[ "$GSC_HDR_MODESET" == "1" ]]; then
          if [[ "$XDG_CURRENT_DESKTOP" == "sway" ]]; then
            curr_colorspace="HDR"
            if command -v sway-toggle-hdr >/dev/null 2>&1; then
              sway-toggle-hdr on
              hdr_mod_enable
            else
              focused_display=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
              swaymsg output $focused_display hdr on
            fi
          elif [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
            # Assuming cm_auto_hdr > 0, switching back to SDR is fine
            hypr-toggle-hdr off
            hdr_mod_disable
          fi

          toggle_vrr
        fi
        last_colorspace="HDR"
      else
        pattern='method return time=* sender=:* -> destination=:* serial=* reply_serial=2'
        if [[ "$line" == $pattern ]]; then
          # Respond to "Switch to Desktop" without -steamos3
          /usr/bin/env steam -shutdown
        fi
      fi
    done

    # Restore VRR if gamescope closes while toggle job is running
    if [[ "$XDG_CURRENT_DESKTOP" == "sway" ]] || [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
      if [[ -n "''${vrr_pid:-}" ]] && ${pkgs.procps}/bin/kill -0 "$vrr_pid" 2>/dev/null; then # "''$()"
        ${pkgs.procps}/bin/kill -9 "$vrr_pid" 2>/dev/null
        wait "$vrr_pid" 2>/dev/null
        ${set_vrr} "1"
      fi
    fi
  '';

  gsc-tv = let debandConfig = pkgs.writeText "deband.conf" ''
    # Ref: https://github.com/DadSchoorse/vkBasalt/issues/225
    effects = deband
    depthCapture = off
    enableOnLaunch = True
    debandAvgdiff = 2.0
    debandMaxdiff = 4.0
    debandMiddiff = 3.0
    debandRange = 20
    debandIterations = 1
  ''; in
  pkgs.writeShellScriptBin "gsc-tv" ''
    pushd ~
    
    if pgrep -x steam >/dev/null; then
      echo "Error: Steam is already running." >&2
      exit 1
    fi

    # Custom Res, Refresh
    OUTPUT="HDMI-A-1"
    WIDTH=3840
    HEIGHT=2160
    REFRESH=120
    SINK="alsa_output.pci-0000_03_00.1.pro-output-9"

    # TODO: Use for more than Sway
    usage() {
      echo "Usage: $0 [-W WIDTH] [-H HEIGHT] [-r REFRESH] [-O OUTPUT]" >&2
      exit 1
    }

    while getopts ":W:H:r:O:A:" opt; do
      case "$opt" in
        W) WIDTH="$OPTARG" ;;
        H) HEIGHT="$OPTARG" ;;
        r) REFRESH="$OPTARG" ;;
        O) OUTPUT="$OPTARG" ;;
        A) SINK="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
      esac
    done

    shift $((OPTIND - 1))

    default_speakers="$(${pkgs.pulseaudio}/bin/pactl get-default-sink)"
    gsr_status="$(${pkgs.systemd}/bin/systemctl --user is-active gpu-screen-recorder.service)"
    
    ${pkgs.pulseaudio}/bin/pactl set-default-sink "$SINK" # TV speakers
    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.HDMI-A-1.enable output.DP-1.disable output.DP-2.disable
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      #cp ~/.config/hypr/displays.conf ~/.config/hypr/displays.conf.gsc
      #cp ~/.config/hypr/displays/tv.conf ~/.config/hypr/displays.conf
      hyprctl keyword "monitorv2[$OUTPUT]:disabled" 0
      hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[].name' | while read -r m; do
        [[ "$m" != "$OUTPUT" ]] && hyprctl keyword "monitorv2[$m]:disabled" 1
      done
      hyprctl keyword "monitorv2[$OUTPUT]:mode" "$WIDTH"x"$HEIGHT"@"$REFRESH"
      hyprctl keyword "monitorv2[$OUTPUT]:scale" 1.5
      hyprctl keyword "monitorv2[$OUTPUT]:vrr" 1
      hyprctl keyword "monitorv2[$OUTPUT]:bitdepth" 10

      # Workaround for HDMI HDR EOTF being broken
      if [[ $OUTPUT == HDMI* ]]; then
        kill `pgrep wl-gammarelay` 2> /dev/null || true
        export GSC_HDR_MOD=1

        # Reduce banding for 4:2:0 chroma
        if [ $((WIDTH * HEIGHT)) -gt $((2560 * 1440)) ]; then
          export ENABLE_VKBASALT=1
          export VKBASALT_CONFIG_FILE="${debandConfig}"
        fi
      fi

      (sleep 2 && [ "$gsr_status" = "active" ] && systemctl --user restart gpu-screen-recorder.service) &
    elif [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      swaymsg output "$OUTPUT" enable mode "$WIDTH"x"$HEIGHT"@"$REFRESH"Hz pos 0 0 render_bit_depth 10 hdr on adaptive_sync on
      swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r --arg output "$OUTPUT" '.[] | select(.name | test($output) | not).name' | ${pkgs.findutils}/bin/xargs -r -I{} swaymsg output {} disable
      (sleep 2 && [ "$gsr_status" = "active" ] && systemctl --user restart gpu-screen-recorder.service) &

      # Workaround for HDMI HDR EOTF being broken
      if [[ $OUTPUT == HDMI* ]]; then
        kill `pgrep wl-gammarelay` 2> /dev/null || true
        export GSC_HDR_MOD=1

        # Reduce banding for 4:2:0 chroma
        if [ $((WIDTH * HEIGHT)) -gt $((2560 * 1440)) ]; then
          export ENABLE_VKBASALT=1
          export VKBASALT_CONFIG_FILE="${debandConfig}"
        fi
      fi
    fi

    # -steamos3 flag prevents DualSense input from passing through the overlay, but limits to 1080p with --xwayland-count 2 -- env STEAM_MULTIPLE_XWAYLANDS=1
    # Doesn't fix all games, and breaks FSR1
    # Allows scripts like steamos-session-select to run when "Switch to Desktop" is selected, which we (can) override
    #  Also seems to prevent AVIF HDR screenshots from saving...
    (sleep 10 && ${pkgs.bluez}/bin/bluetoothctl power on) &
    sleep 3 && env GSC_HDR_MODESET=1 GSC_HDR_MOD="$GSC_HDR_MOD" ${gsc-watcher}/bin/gsc-watcher -e -r $REFRESH -- env ENABLE_VKBASALT="$ENABLE_VKBASALT" steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu
    # sleep 3 && env GSC_HDR_MODESET=1 ${gsc-watcher}/bin/gsc-watcher -e -r $REFRESH -- steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu -steamos3
    # May also disable Bluetooth (toggle is default off...)

    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.enable output.DP-2.enable output.DP-1.position.0,0 output.DP-1.primary output.DP-2.position.2560,180 output.HDMI-A-1.disable # Restore monitor setup
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      #mv ~/.config/hypr/displays.conf.gsc ~/.config/hypr/displays.conf
      if [[ $OUTPUT == HDMI* ]]; then
        kill `pgrep -f wlr-hdr-calibrator` 2> /dev/null || true
        #busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 1
        #busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Gamma d 1
      fi
      hyprctl reload
      (sleep 2 && [ "$gsr_status" = "active" ] && systemctl --user restart gpu-screen-recorder.service) &
    elif [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      if [[ $OUTPUT == HDMI* ]]; then
        kill `pgrep -f wlr-hdr-calibrator` 2> /dev/null || true
      fi
      (${pkgs.coreutils}/bin/timeout 5 kanshi) &
      swaymsg reload # Contains exec_always kanshi
      (sleep 2 && [ "$gsr_status" = "active" ] && systemctl --user restart gpu-screen-recorder.service) &
    fi
    ${pkgs.pulseaudio}/bin/pactl set-default-sink "$default_speakers" # Desktop speakers
  '';
in 
{
  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  	outputs.overlays.modifications
  ];

  programs = {
    steam = {
      extraPackages = with pkgs; [
        gamescope
        gamescope-wsi
      ];

      extraCompatPackages = with pkgs; [
        gamescope-wsi
      ];

      gamescopeSession = {
        enable = true;
        env = {
          #MANGOHUD = "0";
          #MANGOHUD_CONFIG = "read_cfg,no_display";
          #MANGOHUD_CONFIGFILE="~/.config/MangoHud/MangoHud.conf";
          #VK_LOADER_LAYERS_DISABLE = "VK_LAYER_MANGOHUD_overlay_64_x86_64,VK_LAYER_MANGOHUD_overlay_32_x86";
          #WLR_RENDERER = "vulkan";
          DXVK_HDR = "1"; # Works with VKD3D-Proton, confirmed required as of Proton 9.0-3
          ENABLE_GAMESCOPE_WSI = "1";
          ENABLE_HDR_WSI = "0";
          STEAM_MULTIPLE_XWAYLANDS = "1";
          PROTON_ENABLE_AMD_AGS = "1";
          WLR_XWAYLAND = "${pkgs.xwayland}/bin/Xwayland";
        };
        args = [
          "-f"
          "--xwayland-count 2"
          #"--mangoapp"
          #"--expose-wayland" # Seems to break games when HDR enabled
          "--hdr-enabled"
          "--adaptive-sync"
          "-F fsr"
          #"--hdr-debug-force-output"
          #"--hdr-sdr-content-nits 500"
          #"--hdr-itm-enable"
          #"--hdr-itm-target-nits=700"
          #"--hdr-itm-sdr-nits=300"
        ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false; # Needed or gamescope fails within Steam; Band-aided with ananicy
      env = {
        #MANGOHUD = "0";
        #MANGOHUD_CONFIG = "read_cfg,no_display,blacklist=test";
        #MANGOHUD_CONFIGFILE="~/.config/MangoHud/MangoHud.conf";
        #VK_LOADER_LAYERS_DISABLE = "VK_LAYER_MANGOHUD_overlay_64_x86_64,VK_LAYER_MANGOHUD_overlay_32_x86";
        #WLR_RENDERER = "vulkan";
        DXVK_HDR = "1";
        ENABLE_GAMESCOPE_WSI = "1";
        ENABLE_HDR_WSI = "0";
        WLR_XWAYLAND = "${pkgs.xwayland}/bin/Xwayland";
      };
      args = [
        "-f"
        #"--backend sdl" # https://github.com/ValveSoftware/gamescope/issues/1622 and causes stutter (maybe https://github.com/ValveSoftware/gamescope/issues/995)
        "--hdr-enabled"
        "--adaptive-sync"
        "--force-grab-cursor"
        #"-r 360" # Default that is a multiple of 120 and 180
        #"--mangoapp"
        "-F fsr"
        "--fsr-sharpness 8"
        "--hide-cursor-delay 10000"
        "--hdr-sdr-content-nits 203"
        "--hdr-itm-sdr-nits 203"
      ];
    };
  };

  environment = {
  	systemPackages = with pkgs; [
  	  gsc
  	  gsc-tv
  	  gsc-watcher
  	  lsfg-min
  	  lsfg-vk
  	  novrr
  	  wlr-hdr-calibrator

  	  # https://github.com/ValveSoftware/steam-for-linux/issues/11479
  	  # cd to /tmp to somehow avoid stutters with VRR
  	  (if config.programs.steam.gamescopeSession.enable then (pkgs.writeTextDir "share/applications/steam-gamescope.desktop" ''
  	    [Desktop Entry]
  	    Name=Steam (Gamescope)
  	    Comment=Launch Steam via Gamescope (Embedded)
  	    Exec=/usr/bin/env bash -c "cd /tmp && gsc -e -- steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu"
  	    Icon=steam
  	    Type=Application
  	    Categories=Game;
  	  '') else null)
  	  (if config.programs.gamescope.enable then gamescope-wsi else null)
  	];
  };
}
