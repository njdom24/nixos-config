# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [
    ];
  
  services = {
    sunshine = {
      enable = true;
      autoStart = false;
      capSysAdmin = true;
      openFirewall = true;
      settings = {
        key_rightalt_to_key_win = "enabled";
        back_button_timeout = 2000;
        #capture = "kms"; # Sway 1.11 has broken wlr capture over Vulkan
        # vaapi_strict_rc_buffer = "enabled"; https://github.com/LizardByte/Sunshine/issues/3817#issuecomment-3092532936
        min_fps_factor = 3;
      };
      applications.apps = let
        getWaylandDisplay = pkgs.writeShellScript "getWaylandDisplay" ''
          if [ -z "$WAYLAND_DISPLAY" ]; then
	        # Get WAYLAND_DISPLAY from a running process
	        for pid in $(${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/whoami)"); do
	          envfile="/proc/$pid/environ"
	          [ -r "$envfile" ] || continue

	          if wayland_display=$(${pkgs.coreutils}/bin/tr '\0' '\n' < "$envfile" 2>/dev/null \
	            | ${pkgs.gnugrep}/bin/grep '^WAYLAND_DISPLAY=' \
	            | ${pkgs.coreutils}/bin/cut -d= -f2-); then

	            if [ -n "$wayland_display" ]; then
	              echo "$wayland_display"
	              exit 0
	            fi
	          fi
	        done
          fi
          echo $WAYLAND_DISPLAY
        '';
        # Core script
        displayConfig = pkgs.writeShellScript "displayConfig" ''
          # Disable RGB
          $(${pkgs.openrgb}/bin/openrgb --mode static --color 000000 > /dev/null 2>&1 || true) &
          ${pkgs.systemd}/bin/systemctl --user stop gpu-screen-recorder || true

          sleep 1

          echo "Using display: $WAYLAND_DISPLAY"
          session_class="$(${pkgs.systemd}/bin/loginctl show-session "$XDG_SESSION_ID" -p Class --value 2>/dev/null)"
          echo "Session class: $session_class"
          declare -a known_compositors=("kwin_wayland" "Hyprland" "sway")

          # Detect running compositor by process name
          for comp in ''\${known_compositors[@]}''\; do
            if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/whoami)" -f "$comp" > /dev/null; then
              echo "Compositor: $comp"
              
              case "$comp" in
                sway)
                  echo "→ Running sway-specific logic"
                  export XDG_CURRENT_DESKTOP="sway"
                  if [ -z "$SWAYSOCK" ]; then
                    export SWAYSOCK=/run/user/$(${pkgs.coreutils}/bin/id -u)/sway-ipc.$(${pkgs.coreutils}/bin/id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
                  fi

                  # Check if any HEADLESS output exists (HEADLESS-1, HEADLESS-2, etc.)
                  existing_headless=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\")) | .name")
                  
                  if [ -z "$existing_headless" ]; then
                    # If no HEADLESS output exists, create one
                    ${pkgs.sway}/bin/swaymsg create_output
                  fi
                  # Disable all non-HEADLESS outputs
                  if [ "$session_class" != "greeter" ]; then
                    ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable
                  fi

                  # Configure display to match client
                  if ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "HEADLESS-1")' > /dev/null; then
                    mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
                    ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode $mode
                  else
                    echo "Error: Not headless"
                    exit 1
                  fi
                  
                  if [[ "$1" == "hdr" ]]; then
                    echo "Enabling HDR"
                    ${pkgs.sway}/bin/swaymsg output HEADLESS-1 render_bit_depth 10
                  else
                    echo "Disabling HDR"
                    ${pkgs.sway}/bin/swaymsg output HEADLESS-1 render_bit_depth 8
                  fi
                  
                  ;;
                kwin_wayland)
                  echo "→ Running KDE/KWin-specific logic"
                  export XDG_CURRENT_DESKTOP="KDE"
                  
                  # Assume dummy display used for headless
                  DUMMY="HDMI-A-1"

                  # Configure display to match client
                  if [ "$SUNSHINE_CLIENT_FPS" -gt 120 ]; then
                    SUNSHINE_CLIENT_FPS=120
                  fi

                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".enable
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".mode."$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"
                  
                  output=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o)
                  
                  # Extract the names of the connected displays
                  displays=$(echo "$output" | ${pkgs.gawk}/bin/awk '/Output:/ { print $3 }')
                  echo "Displays found: $displays"

                  # Check if the dummy display is present
                  echo "$displays" | grep -qx "$DUMMY"
                  if [ $? -ne 0 ]; then
                      echo "$DUMMY is not connected. Exiting."
                      exit 1
                  fi
                  
                  # Loop through each display and disable all except DUMMY
                  while read -r display; do
                    if [[ "$display" != "$DUMMY" ]]; then
                      echo "Disabling display: $display"
                      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$display".disable
                    fi
                  done <<< "$displays"
                  
                  if [[ "$1" == "hdr" ]]; then
                    echo "Enabling HDR"
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".wcg.enable output."$DUMMY".hdr.enable
                    # https://github.com/LizardByte/Sunshine/issues/3298#issuecomment-2670218658
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferAccuracy
                    #${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".sdr-brightness.203 # Standard reference luminance
                    ${pkgs.kdePackages.full}/bin/qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness 10000 # Max 100.00% brightness
                    ${pkgs.kdePackages.kscreen}/bin/hdrcalibrator "$DUMMY" & # Present calibration GUI
                  else
                    echo "Disabling HDR"
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".hdr.disable output."$DUMMY".wcg.disable
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferEfficiency
                  fi
                  ;;
                Hyprland)
                  echo "→ Running Hyprland-specific logic"
                  export XDG_CURRENT_DESKTOP="Hyprland"

                  display_cfg="/home/$USER/.config/hypr/displays.conf"
                  if [[ ! -f "$display_cfg".gsc ]]; then
                    # Make backup
                    cp "$display_cfg" "$display_cfg".gsc
                  fi

                  # Configure display to match client
                  if [ "$SUNSHINE_CLIENT_FPS" -gt 120 ]; then
                    SUNSHINE_CLIENT_FPS=120
                  fi

                  tmpfile=$(${pkgs.mktemp}/bin/mktemp)

                  ${pkgs.coreutils}/bin/printf "%s\n" \
                    "monitorv2 {" \
                    "	output = HDMI-A-1" \
                    "	mode = ''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}" \
                    "	position = 0x0" \
                    "	scale = 1" \
                    "	transform = 0" \
                    "	vrr = 0" \
                    "	sdr_min_luminance = 0.005" \
                    "	sdr_max_luminance = 203" \
                    "	min_luminance = 0" \
                    "	max_luminance = 203" \
                    "	max_avg_luminance = 203" \
                    "	cm = srgb" \
                    "	supports_wide_color = 0" \
                    "	supports_hdr = 0" \
                    "	bitdepth = 8" \
                    "}" \
                    "" \
                    "monitor = DP-1, disable" \
                    "monitor = DP-2, disable" \
                    "monitor = DP-3, disable" \
                    > "$tmpfile"

                  # "''$()"

                  if [[ "$1" == "hdr" ]]; then
                    echo "Enabling HDR"
                    #${pkgs.gnused}/bin/sed -i 's/cm = srgb/cm = hdr/' "$tmpfile"
                    ${pkgs.gnused}/bin/sed -i 's/bitdepth = 8/bitdepth = 10/' "$tmpfile"
                    ${pkgs.gnused}/bin/sed -i 's/max_luminance = 203/max_luminance = 1000/' "$tmpfile"
                    ${pkgs.gnused}/bin/sed -i 's/max_avg_luminance = 203/max_avg_luminance = 1000/' "$tmpfile"
                    ${pkgs.gnused}/bin/sed -i 's/supports_wide_color = 0/supports_wide_color = 1/' "$tmpfile"
                    ${pkgs.gnused}/bin/sed -i 's/supports_hdr = 0/supports_hdr = 1/' "$tmpfile"
                  fi

                  mv -f "$tmpfile" ~/.config/hypr/displays.conf

                  ${pkgs.procps}/bin/kill $($pkgs.procps}/bin/pgrep hyprland-share) || true
                  ;;
                "")
                  echo "→ No known compositor found"
                  ;;
                *)
                  echo "→ Unknown compositor: $compositor"
                  ;;
              esac
              
              exit 0
            fi
          done
          
          echo "Compositor: Unknown"
        '';

      undoConfig = pkgs.writeShellScript "undoConfig" ''
        session_class="$(${pkgs.systemd}/bin/loginctl show-session "$XDG_SESSION_ID" -p Class --value 2>/dev/null)"
        if [ "$session_class" = "greeter" ]; then
          echo "Running in greeter. Nothing to undo"
          exit 0
        fi

        if [ -z "$REMOTE_ENABLED" ]; then
          REMOTE_ENABLED=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^REMOTE_ENABLED=' | ${pkgs.coreutils}/bin/cut -d= -f2)
        fi
        
        if [ "$REMOTE_ENABLED" = "1" ]; then
          echo "Fully-remote session. Keeping physical displays disabled"
          exit 0
        fi

        export WAYLAND_DISPLAY=$(${getWaylandDisplay})
        echo "Using display: $WAYLAND_DISPLAY"
        declare -a known_compositors=("kwin_wayland" "Hyprland" "sway")

        # Detect running compositor by process name
        for comp in ''\${known_compositors[@]}''\; do
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/whoami)" -f "$comp" > /dev/null; then
            echo "Compositor: $comp"
            
            case "$comp" in
              sway)
                echo "→ Running sway-specific logic"
                export XDG_CURRENT_DESKTOP="sway"
                if [ -z "$SWAYSOCK" ]; then
                  export SWAYSOCK=/run/user/$(${pkgs.coreutils}/bin/id -u)/sway-ipc.$(${pkgs.coreutils}/bin/id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
                fi

                $(${pkgs.coreutils}/bin/timeout 5 ${pkgs.kanshi}/bin/kanshi) &
                ;;
              kwin_wayland)
                echo "→ Running KDE/KWin-specific logic"
                export XDG_CURRENT_DESKTOP="KDE"
                
                # Assume dummy display used for headless
                DUMMY="HDMI-A-1"

                # Get all connected and enabled outputs
                outputs=($(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j | ${pkgs.jq}/bin/jq -r '
                  .outputs[]
                  | select(.connected == true and .enabled == true)
                  | .name
                '))
                
                len=''${#outputs[@]}
                first=''${outputs[0]:-}

                if [[ $len -eq 0 || ( $len -eq 1 && ( "$first" == "$DUMMY" || "$first" == "$DP-3" ) ) ]]; then
                  echo "Only dummy is enabled and connected. Restoring..."
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.enable
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-2.enable
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.disable
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".disable
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.primary
                else
                  echo "Dummy is not the only enabled connected output"
                fi
                ;;
              Hyprland)
                echo "→ Running Hyprland-specific logic"
                export XDG_CURRENT_DESKTOP="Hyprland"

                display_cfg="/home/$USER/.config/hypr/displays.conf"
                if [[ -f "$display_cfg".gsc ]]; then
                  mv -f "$display_cfg".gsc "$display_cfg"
                fi
                ;;
              "")
                echo "→ No known compositor found"
                ;;
              *)
                echo "→ Unknown compositor: $compositor"
                ;;
            esac
            
            exit 0
          fi
        done
        
        echo "Compositor: Unknown"
      '';

      gamescopeConfig = pkgs.writeShellScript "gamescopeConfig" ''
        if ${pkgs.procps}/bin/pgrep -f ".gamescope-wrapped" > /dev/null || \
           ${pkgs.procps}/bin/pgrep -x "gamescope" > /dev/null || \
           ${pkgs.procps}/bin/pgrep -x "gamescope-wl" > /dev/null; then

          echo "Gamescope is running. Adjusting"
          
          if [[ "$1" == "hdr" ]]; then
            echo "Enabling HDR"
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 1
          else
            echo "Disabling HDR"
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 0
          fi
          ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $SUNSHINE_CLIENT_FPS
        else
          echo "gamescope is not running. Starting"
          ${pkgs.systemd}/bin/systemctl --user reset-failed
          ${pkgs.gamescope}/bin/gamescopectl shutdown 2> /dev/null || true
          ${pkgs.systemd}/bin/systemctl --user stop sunshine-steam.service 2> /dev/null || true
          ${pkgs.systemd}/bin/systemctl --user reset-failed

          ${pkgs.systemd}/bin/systemd-run --user --unit=sunshine-steam --remain-after-exit --description="Launch Steam Gamescope detached in desktop session" ${pkgs.bash}/bin/bash -c 'gsc -e -- steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu'
        fi
      '';
      in
      [
        {
          name = "Desktop HDR";
          image-path = "${./desktop_hdr.png}";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "desktop-hdr" ''
                export WAYLAND_DISPLAY=$(${getWaylandDisplay})
                ${displayConfig} hdr > /tmp/sunshine_log_$UID.txt 2>&1
              '';
              undo = undoConfig;
            }
          ];
        }

        {
          name = "Desktop SDR";
          image-path = "desktop-alt.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "desktop-sdr" ''
                export WAYLAND_DISPLAY=$(${getWaylandDisplay})
                ${displayConfig} sdr > /tmp/sunshine_log_$UID.txt 2>&1
              '';
              undo = undoConfig;
            }
          ];
        }

        {
          name = "Steam HDR";
          image-path = "${./steam_hdr.png}";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "steam-hdr" ''
                export WAYLAND_DISPLAY=$(${getWaylandDisplay})
                ${displayConfig} hdr > /tmp/sunshine_log_$UID.txt 2>&1
                ${gamescopeConfig} hdr > /tmp/sunshine_log_$UID.txt 2>&1
              '';
              undo = undoConfig;
            }
          ];
        }

        {
          name = "Steam SDR";
          image-path = "steam.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "steam-sdr" ''
                export WAYLAND_DISPLAY=$(${getWaylandDisplay})
                ${displayConfig} sdr > /tmp/sunshine_log_$UID.txt 2>&1
                ${gamescopeConfig} sdr > /tmp/sunshine_log_$UID.txt 2>&1
              '';
              undo = undoConfig;
            }
          ];
        }

        #{
        #  name = "Legacy";
        #  image-path = "desktop.png";
        #  prep-cmd = [
        #    {
        #      do = pkgs.writeShellScript "set-client-res" ''
        #        if [ -z "$SWAYSOCK" && -z "$WAYLAND_DISPLAY" ]; then
        #          SWAYSOCK=/run/user/$(id -u)/sway-ipc.$(id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
        #        fi
        #        
        #        if ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "HEADLESS-1")' > /dev/null; then
        #          mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
        #          ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode $mode
        #        else
        #          echo "Not headless"
        #        fi
        #      '';
        #    }
        #  ];
        #}
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "sunshine-pin" ''
      #!/usr/bin/env bash

      read -p "Username: " username
      read -s -p "Password: " password
      echo
      read -p "Name: " name
      read -p "PIN: " pin

      url="https://localhost:47990/api/pin"

      response=$(curl -s -k -u "$username:$password" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"pin\":\"$pin\"}" \
        "$url")

      echo "Server response:"
      echo "$response"
    '')
  ];
}
