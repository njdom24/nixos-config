# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let
  # Patched for improved VRR
  gamescope_immediate = pkgs.gamescope.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches) ++ [
      ../../../../../patches/gamescope-vblank-hack.patch
    ];
  });
  # Work around HDR needing an extra "push" with VMM7100 Firmware v124 (VRR, HDR, 4k144Hz)
  vmm7100_hdr_fix = pkgs.writeShellScript "vmm7100-hdr-fix" ''
    #!/usr/bin/env bash

    if [[ "$XDG_CURRENT_DESKTOP" = "gamescope" ]]; then
      XDG_CURRENT_DESKTOP="$_GSC_PARENT_DESKTOP"
      DISPLAY="$_GSC_PARENT_DISPLAY"
      WAYLAND_DISPLAY="$_GSC_PARENT_WAYLAND_DISPLAY"
      XDG_SESSION_TYPE="$_GSC_PARENT_SESSION_TYPE"
    fi

    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.wcg.enable output.DP-3.hdr.enable 
      # TODO: Get current mode and reapply
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.mode.3840x2160@60 && ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.mode.3840x2160@120
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-3,3840x2160@60,auto,1,cm,hdr
      ${pkgs.hyprland}/bin/hyprctl reload
    fi
  '';

  # Resolution & refresh detection
  get_display_mode = pkgs.writeShellScript "get-display-mode.sh" ''
    # Sway 1.11 sets this OOTB now
    if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
      ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '
        .[] | select(.focused) | "\(.current_mode.width) \(.current_mode.height) \(.current_mode.refresh / 1000)"
      '
    elif [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
      read width height refresh <<< $(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '
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

      # --- MANGOHUD_FPS_LIMIT ---
      if [ -n "$MANGOHUD_FPS_LIMIT" ]; then
        new_limit=$((MANGOHUD_FPS_LIMIT * 2))
        export MANGOHUD_FPS_LIMIT="$new_limit"
        echo "New MANGOHUD_FPS_LIMIT: $MANGOHUD_FPS_LIMIT"
      fi

      # --- MANGOHUD_CONFIG ---
      if [ -n "$MANGOHUD_CONFIG" ]; then
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

    exec "$@"
  '';

  # Gamescope helper to auto-fill mode, HDR, update settings
  gsc = pkgs.writeShellScriptBin "gsc" ''
    #!/usr/bin/env bash
    set -eo pipefail

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

      if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
        echo "0 0 0"
      elif [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
        conf="$HOME/.config/hypr/displays.conf"
        
        focused_monitor=$(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[] | select(.focused==true) | .name')
        
        block=$(${pkgs.gawk}/bin/awk -v mon="$focused_monitor" '
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
        cm=$(${pkgs.gawk}/bin/awk -F'=' '/^[[:space:]]*cm[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$block")
        sdr_max=$(${pkgs.gawk}/bin/awk -F'=' '/^[[:space:]]*sdr_max_luminance[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$block")
        max_lum=$(${pkgs.gawk}/bin/awk -F'=' '/^[[:space:]]*max_luminance[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' <<< "$block")
     
        if [[ "$hdr_support" = "1" || "$cm" = "hdr" || "$cm" = "hdredid" ]]; then
          echo "1 $sdr_max $max_lum"
        else
          echo "0 0 0"
        fi
      elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
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

    # Try to enable/disable RenoDX HDR ReShade automatically
    if [[ -v RENODX_HDR && "$RENODX_HDR" == "1" ]]; then
      reshade_file="$(${pkgs.coreutils}/bin/timeout 5 ${pkgs.findutils}/bin/find "$PWD" -type f -name 'ReShade.ini' | ${pkgs.coreutils}/bin/head -n 1)"

      if [[ -n "$reshade_file" ]]; then
        reshade_dir="$(dirname "$reshade_file")"
        # Find matching .addon64 file containing 'renodx'
        addon_file="$(${pkgs.findutils}/bin/find "$reshade_dir" -maxdepth 1 -type f -name '*.addon64' -printf '%f\n' | ${pkgs.gnugrep}/bin/grep renodx | head -n1)"
        addon_id="RenoDX@$addon_file"
        
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
          # Scale peak brightness by luminance multiplier from base of 203 nits
          scale=$(echo "scale=4; $hdr_paper_white / 203" | ${pkgs.bc}/bin/bc)
          adjusted_peak=$(echo "$hdr_peak / $scale" | ${pkgs.bc}/bin/bc)
          # Set peak brightness
          ${pkgs.gnused}/bin/sed -i "s/^ToneMapPeakNits=.*/ToneMapPeakNits=$adjusted_peak/" "$reshade_file"
        
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
    fi
    
    while true; do
      if env -u LD_PRELOAD ${gamescope_immediate}/bin/gamescope ${
        lib.concatMapStringsSep " " (arg: lib.escapeShellArgs (lib.splitString " " arg))
        config.programs.gamescope.args
      #} -r "$refresh" -w "$width" -h "$height" -W "$width" -H "$height" $mangoapp_flag "''${extra_flags[@]}" -- env DXVK_HDR="$hdr_enabled" LD_PRELOAD="$ld_preload_pass" ${pkgs.libstrangle}/bin/strangle $refresh "''${to_run[@]}"; then
      } -r "$refresh" -w "$width" -h "$height" -W "$width" -H "$height" $mangoapp_flag "''${extra_flags[@]}" -- env DXVK_HDR="$hdr_enabled" LD_PRELOAD="$ld_preload_pass" "''${to_run[@]}"; then
        ## } -r "$refresh" -W "$width" -H "$height" $mangoapp_flag "$@"; then
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

      #if [[ "$_GSC_PARENT_DESKTOP" == "Hyprland" || "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
      #  hypr-toggle-hdr off
      #fi
    done

    #if [[ -v mangoapp_file ]]; then
    #  rm -f "$mangoapp_file"
    #fi
    if [[ -v mangohud_file ]]; then
      rm -f "$mangohud_file"
    fi
  '';

  # Convenience script. Hacky, but seems to get VRR going stable too
  gsc-vmm7100 = pkgs.writeShellScriptBin "gsc-vmm7100" ''
    pushd ~
    
    if pgrep -x steam >/dev/null; then
      echo "Error: Steam is already running." >&2
      exit 1
    fi
    
    ${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-8 # TV speakers
    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.enable output.DP-1.disable output.DP-2.disable
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      cp ~/.config/hypr/displays.conf ~/.config/hypr/displays.conf.gsc
      cp ~/.config/hypr/displays/tv.conf ~/.config/hypr/displays.conf
      $(sleep 2 && systemctl --user is-active --quiet gpu-screen-recorder.service && systemctl --user restart gpu-screen-recorder.service) &
    fi
    
    timeout 5 ${gsc}/bin/gsc -- ${pkgs.mesa-demos}/bin/vkgears

    # TODO: Make extra confs for Hyprland if VRR is still an issue
    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      $(sleep 20 && ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.vrrpolicy.never && sleep 20 && ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.vrrpolicy.automatic) &
    fi
    sleep 3 && ${gsc}/bin/gsc -e -F fsr -- ${pkgs.steam}/bin/steam -gamepadui -pipewire-dmabuf -console -cef-force-gpu

    if [[ "$XDG_CURRENT_DESKTOP" = "KDE" ]]; then
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.enable output.DP-2.enable output.DP-1.position.0,0 output.DP-1.primary output.DP-2.position.2560,180 output.DP-3.disable # Restore monitor setup
    elif [[ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]]; then
      mv ~/.config/hypr/displays.conf.gsc ~/.config/hypr/displays.conf
      $(sleep 2 && systemctl --user is-active --quiet gpu-screen-recorder.service && systemctl --user restart gpu-screen-recorder.service) &
    fi
    ${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3 # Desktop speakers
  '';
in 
{
  imports =
    [ ] ++ (builtins.attrValues outputs.nixosModules);

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
        STEAM_MULTIPLE_XWAYLANDS = "1";
      };
      args = [
        "-f"
        "--xwayland-count 2"
        #"--backend sdl" # https://github.com/ValveSoftware/gamescope/issues/1622 and causes stutter (maybe https://github.com/ValveSoftware/gamescope/issues/995)
        "--hdr-enabled"
        "--adaptive-sync"
        "--force-grab-cursor" # Breaks games with launchers (Elden Ring)
        #"-r 360" # Default that is a multiple of 120 and 180
        #"--mangoapp"
        "--hide-cursor-delay 10000"
      ];
    };
  };

  environment = {
  	systemPackages = with pkgs; [
  	  gsc
  	  gsc-vmm7100
  	  lsfg-min
  	  lsfg-vk

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
