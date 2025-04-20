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
      applications.apps = let
        # Core script
        displayConfig = pkgs.writeShellScript "displayConfig" ''
          #!/usr/bin/env bash
          
          user="$(${pkgs.coreutils}/bin/whoami)"
          declare -a known_compositors=("sway" "kwin_wayland")

          if [ -z "$WAYLAND_DISPLAY" ]; then
	        # Get WAYLAND_DISPLAY from a running process
	        for pid in $(${pkgs.procps}/bin/pgrep -u "$user"); do
	          envfile="/proc/$pid/environ"
	          [ -r "$envfile" ] || continue
	          
	          wayland_display=$(${pkgs.coreutils}/bin/tr '\0' '\n' < "$envfile" | ${pkgs.gnugrep}/bin/grep '^WAYLAND_DISPLAY=' | ${pkgs.coreutils}/bin/cut -d= -f2-)
	          if [ -n "$wayland_display" ]; then
	            export WAYLAND_DISPLAY=$wayland_display
	            echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
	            break
	          fi
	        done
          fi

          echo "WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
          
          # Detect running compositor by process name
          for comp in ''\${known_compositors[@]}''\; do
            if ${pkgs.procps}/bin/pgrep -u "$user" -f "$comp" > /dev/null; then
              echo "Compositor: $comp"
              
              case "$comp" in
                sway)
                  echo "→ Running sway-specific logic"
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
                  ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable

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
                    ${pkgs.sway}/bin/swaymsg output HEADLESS-1 render_bit_depth 10
                  fi
                  
                  ;;
                kwin_wayland)
                  echo "→ Running KDE/KWin-specific logic"
                  # Assume DP-3 is a dummy display used for headless
                  DUMMY="DP-3"

                  # Configure display to match client
                  ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".mode."$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"

                  if [ "$SUNSHINE_CLIENT_FPS" -gt 120 ]; then
                    SUNSHINE_CLIENT_FPS=120
                  fi

                  if [ "$SUNSHINE_CLIENT_HEIGHT" -gt 1440 ]; then
                    SUNSHINE_CLIENT_FPS=60
                  fi
                  
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
                  
                  # Loop through each display and disable all except DP-3
                  while read -r display; do
                    if [[ "$display" != "$DUMMY" ]]; then
                      echo "Disabling display: $display"
                      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$display".disable
                    fi
                  done <<< "$displays"
                  
                  if [[ "$1" == "hdr" ]]; then
                    echo "Enabling HDR"
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".hdr.enable
                    # https://github.com/LizardByte/Sunshine/issues/3298#issuecomment-2670218658
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferAccuracy
                  else
                    echo "Disabling HDR"
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".hdr.disable
                    ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferEfficiency
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
        #!/usr/bin/env bash
        
        if ${pkgs.procps}/bin/pgrep -f gamescope > /dev/null; then
          echo "gamescope is running. Adjusting"
          
          if [[ "$1" == "hdr" ]]; then
            echo "Enabling HDR"
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 1
          else
            echo "Disabling HDR"
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 0
          fi
        else
          echo "gamescope is not running. Starting"
          export DXVK_HDR=1 # Can't be adjusted at runtime. Toggle in-game if need be
          export ENABLE_GAMESCOPE_WSI=1
          export ENABLE_HDR_WSI=1
          export PROTON_ENABLE_AMD_AGS=1
          export STEAM_MULTIPLE_XWAYLANDS=1
          if [[ "$1" == "hdr" ]]; then
            gamescope --steam --hdr-enabled -- steam -tenfoot -pipewire-dmabuf
          else
            gamescope --steam -- steam -tenfoot -pipewire-dmabuf
          fi
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
                #!/usr/bin/env bash > /tmp/sunshine_log.txt 2>&1
                ${displayConfig} hdr > /tmp/sunshine_log.txt 2>&1
              '';
            }
          ];
        }

        {
          name = "Desktop SDR";
          image-path = "desktop-alt.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "desktop-sdr" ''
                #!/usr/bin/env bash > /tmp/sunshine_log.txt 2>&1
                ${displayConfig} sdr > /tmp/sunshine_log.txt 2>&1
              '';
            }
          ];
        }

        {
          name = "Steam HDR";
          image-path = "${./steam_hdr.png}";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "steam-hdr" ''
                #!/usr/bin/env bash
                ${displayConfig} hdr > /tmp/sunshine_log.txt 2>&1
                ${gamescopeConfig} hdr > /tmp/sunshine_log.txt 2>&1
              '';
            }
          ];
        }

        {
          name = "Steam SDR";
          image-path = "steam.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "steam-sdr" ''
                #!/usr/bin/env bash
                ${displayConfig} sdr > /tmp/sunshine_log.txt 2>&1
                ${gamescopeConfig} sdr > /tmp/sunshine_log.txt 2>&1
              '';
            }
          ];
        }

        {
          name = "Legacy";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "set-client-res" ''
                #!/usr/bin/env bash
                if [ -z "$SWAYSOCK" && -z "$WAYLAND_DISPLAY" ]; then
                  SWAYSOCK=/run/user/$(id -u)/sway-ipc.$(id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
                fi
                
                if ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "HEADLESS-1")' > /dev/null; then
                  mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
                  ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode $mode
                else
                  echo "Not headless"
                fi
              '';
            }
          ];
        }
      ];
    };
  };
}
