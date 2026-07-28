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
        capture = "kms"; # Sway 1.11 has broken wlr capture over Vulkan
        encoder = "vulkan";
        vk_rc_mode = 4; # VBR, 2 = CBR
        # vaapi_strict_rc_buffer = "enabled"; https://github.com/LizardByte/Sunshine/issues/3817#issuecomment-3092532936
        min_fps_factor = 3;
        ds5_inputtino_randomize_mac = "disabled";
      };
      applications.apps = let
        getWaylandDisplay = pkgs.writeShellScript "getWaylandDisplay" ''
          if [[ -z "$WAYLAND_DISPLAY" ]]; then
            session_class="$(${pkgs.systemd}/bin/loginctl show-session "$XDG_SESSION_ID" -p Class --value 2>/dev/null)"
            if [ "$session_class" != "greeter" ]; then
              WAYLAND_DISPLAY=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^WAYLAND_DISPLAY=' | ${pkgs.coreutils}/bin/cut -d= -f2)
            fi
          fi
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

          if [[ -z "$XDG_CURRENT_DESKTOP" && "$session_class" != "greeter" ]]; then
            XDG_CURRENT_DESKTOP=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^XDG_CURRENT_DESKTOP=' | ${pkgs.coreutils}/bin/cut -d= -f2)
          fi

          if [[ -z "$XDG_CURRENT_DESKTOP" ]]; then
            # Detect running compositor by process name
            for comp in ''\${known_compositors[@]}''\; do
              if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/whoami)" -f "$comp" > /dev/null; then
                echo "Compositor: $comp"
                case "$comp" in
                  sway)
                    export XDG_CURRENT_DESKTOP="sway"
                    ;;
                  kwin_wayland)
                    export XDG_CURRENT_DESKTOP="KDE"
                    ;;
                  Hyprland)
                    export XDG_CURRENT_DESKTOP="Hyprland"
                    ;;
                  *)
                    echo "→ Unknown compositor: $compositor"
                    ;;
                esac
              fi
            done
          fi

          # Assume dummy display used for headless
          DUMMY="DP-3"

          case "$XDG_CURRENT_DESKTOP" in
            sway)
              echo "→ Running sway-specific logic"
              if [ -z "$SWAYSOCK" ] && [ "$session_class" != "greeter" ]; then
                export SWAYSOCK=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^SWAYSOCK=' | ${pkgs.coreutils}/bin/cut -d= -f2)
              fi
              if [ -z "$SWAYSOCK" ]; then
                export SWAYSOCK=/run/user/$(${pkgs.coreutils}/bin/id -u)/sway-ipc.$(${pkgs.coreutils}/bin/id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
              fi

              existing_dummy=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"$DUMMY\")) | .name")
              # Check if any HEADLESS output exists (HEADLESS-1, HEADLESS-2, etc.)
              existing_headless=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\")) | .name")

              if [ -z "$existing_dummy" ]; then
                # TODO: Won't work with kmsgrab forced. Need to find a way to force wlroots capture method...
                if [ -z "$existing_headless" ]; then
                  # If no HEADLESS output exists, create one
                  ${pkgs.sway}/bin/swaymsg create_output
                fi
                existing_headless=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\")) | .name")
                STREAMING_OUTPUT="$existing_headless"
              else
                STREAMING_OUTPUT="$DUMMY"
                ${pkgs.sway}/bin/swaymsg output $DUMMY enable
                #${pkgs.sway}/bin/swaymsg output $existing_headless disable
                ${pkgs.sway}/bin/swaymsg output $existing_headless unplug 2> /dev/null || true
              fi

              # Disable all non-HEADLESS outputs
              if [ "$session_class" != "greeter" ]; then
                ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"$STREAMING_OUTPUT\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable
              fi

              # Configure display to match client
              if ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -e --arg out "$STREAMING_OUTPUT" '.[] | select(.name == $out)' > /dev/null; then
                if [[ "$STREAMING_OUTPUT" == "$DUMMY" ]]; then
                  if [ "$SUNSHINE_CLIENT_FPS" -gt 120 ]; then
                    SUNSHINE_CLIENT_FPS=120
                  fi
                fi
                mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
                ${pkgs.sway}/bin/swaymsg output "$STREAMING_OUTPUT" mode "$mode"
              else
                echo "Error: Not headless"
                # Don't return failure, allow the stream to go through
                exit 0
              fi

              supports_hdr="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$STREAMING_OUTPUT\") | .features.hdr")"
              if [[ "$1" == "hdr" && "$supports_hdr" == "true" ]]; then
                echo "Enabling HDR"
                ${pkgs.sway}/bin/swaymsg output $STREAMING_OUTPUT render_bit_depth 10 hdr on
              else
                if [[ "$supports_hdr" == "true" ]]; then
                  echo "Disabling HDR"
                  ${pkgs.sway}/bin/swaymsg output $STREAMING_OUTPUT render_bit_depth 10 hdr off
                else
                  ${pkgs.sway}/bin/swaymsg output $STREAMING_OUTPUT render_bit_depth 10
                fi
              fi
              ;;
            KDE)
              echo "→ Running KDE/KWin-specific logic"

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

              # Streaming setup sometimes screws with display config on subsequent logins
              # This allows restoring the previous config: https://discuss.kde.org/t/solved-is-there-any-way-to-reset-monitor-configuration/25998/2
              rm -f "/home/$USER/.config/kwinoutputconfig.json"

              if [[ "$1" == "hdr" ]]; then
                echo "Enabling HDR"
                ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".wcg.enable output."$DUMMY".hdr.enable
                # https://github.com/LizardByte/Sunshine/issues/3298#issuecomment-2670218658
                ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferAccuracy
                #${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".sdr-brightness.203 # Standard reference luminance
                ${pkgs.qt6.qttools}/bin/qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness 10000 # Max 100.00% brightness
                #${pkgs.kdePackages.kscreen}/bin/hdrcalibrator "$DUMMY" & # Present calibration GUI
              else
                echo "Disabling HDR"
                ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".hdr.disable output."$DUMMY".wcg.disable
                ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".colorPowerTradeoff.preferEfficiency
              fi
              ;;
            Hyprland)
              echo "→ Running Hyprland-specific logic"

              if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
                export HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^HYPRLAND_INSTANCE_SIGNATURE=' | ${pkgs.coreutils}/bin/cut -d= -f2)
              fi
              if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
                export HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.hyprland}/bin/hyprctl -j instances | ${pkgs.jq}/bin/jq -r '.[0] | .instance')
              fi

              # Configure display to match client
              if [ "$SUNSHINE_CLIENT_FPS" -gt 120 ]; then
                SUNSHINE_CLIENT_FPS=120
              fi
              
              ${pkgs.hyprland}/bin/hyprctl eval "hl.monitor({ output = \"$DUMMY\", disabled = false })"
              ${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[].name' | while read -r m; do
                [[ "$m" != "$DUMMY" ]] && ${pkgs.hyprland}/bin/hyprctl eval "hl.monitor({ output = \"$m\", disabled = true })"
              done
              
              if [[ "$1" == "hdr" ]]; then
                echo "Enabling HDR"
                ${pkgs.hyprland}/bin/hyprctl eval "hl.monitor({
                  output               = \"$DUMMY\",
                  mode                 = \"''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}\",
                  position             = \"0x0\",
                  bitdepth             = 10,
                  cm                   = \"srgb\",
                  supports_wide_color  = true,
                  supports_hdr         = true,
                  sdr_min_luminance    = 0.005,
                  sdr_max_luminance    = 203,
                  min_luminance        = 0,
                  max_luminance        = 1000,
                  max_avg_luminance    = 1000
                })"
              else
                echo "Disabling HDR"
                ${pkgs.hyprland}/bin/hyprctl eval "hl.monitor({
                  output               = \"$DUMMY\",
                  mode                 = \"''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}\",
                  position             = \"0x0\",
                  bitdepth             = 10,
                  cm                   = \"srgb\",
                  supports_wide_color  = false,
                  supports_hdr         = false,
                  sdr_min_luminance    = 0.005,
                  sdr_max_luminance    = 80,
                  min_luminance        = 0,
                  max_luminance        = 80,
                  max_avg_luminance    = 80
                })"
              fi
              
              ${pkgs.hyprland}/bin/hyprctl eval "hl.config({ render = { cm_auto_hdr = 1 } })"
              
              ${pkgs.procps}/bin/kill $(${pkgs.procps}/bin/pgrep hyprland-share) || true
              ;;
            "")
              echo "→ No known compositor found"
              ;;
            *)
              echo "→ Unknown compositor: $compositor"
              ;;
          esac
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

        if [[ -z "$XDG_CURRENT_DESKTOP" && "$session_class" != "greeter" ]]; then
          XDG_CURRENT_DESKTOP=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^XDG_CURRENT_DESKTOP=' | ${pkgs.coreutils}/bin/cut -d= -f2)
        fi

        if [[ -z "$XDG_CURRENT_DESKTOP" ]]; then
          # Detect running compositor by process name
          for comp in ''\${known_compositors[@]}''\; do
            if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/whoami)" -f "$comp" > /dev/null; then
              echo "Compositor: $comp"
              case "$comp" in
                sway)
                  export XDG_CURRENT_DESKTOP="sway"
                  ;;
                kwin_wayland)
                  export XDG_CURRENT_DESKTOP="KDE"
                  ;;
                Hyprland)
                  export XDG_CURRENT_DESKTOP="Hyprland"
                  ;;
                *)
                  echo "→ Unknown compositor: $compositor"
                  ;;
              esac
            fi
          done
        fi
            
        case "$XDG_CURRENT_DESKTOP" in
          sway)
            echo "→ Running sway-specific logic"

            if [ -z "$SWAYSOCK" ]; then
              export SWAYSOCK=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^SWAYSOCK=' | ${pkgs.coreutils}/bin/cut -d= -f2)
            fi
            if [ -z "$SWAYSOCK" ]; then
              export SWAYSOCK=/run/user/$(${pkgs.coreutils}/bin/id -u)/sway-ipc.$(${pkgs.coreutils}/bin/id -u).$(${pkgs.procps}/bin/pgrep -x sway).sock
            fi

            (${pkgs.coreutils}/bin/timeout 5 ${pkgs.kanshi}/bin/kanshi) &
            (sleep 5 && swaymsg reload) &
            ;;
          KDE)
            echo "→ Running KDE/KWin-specific logic"

            # Assume dummy display used for headless
            DUMMY="DP-3"

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

            if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
              export HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnugrep}/bin/grep '^HYPRLAND_INSTANCE_SIGNATURE=' | ${pkgs.coreutils}/bin/cut -d= -f2)
            fi
            if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
              export HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.hyprland}/bin/hyprctl -j instances | ${pkgs.jq}/bin/jq -r '.[0] | .instance')
            fi

            ${pkgs.hyprland}/bin/hyprctl reload
            ;;
          *)
            echo "→ Unknown compositor: $compositor"
            ;;
        esac
      '';

      gamescopeConfig = pkgs.writeShellScript "gamescopeConfig" ''
        if ${pkgs.procps}/bin/pgrep -f ".gamescope-wrapped" > /dev/null || \
          ${pkgs.procps}/bin/pgrep -x "gamescope" > /dev/null || \
          ${pkgs.procps}/bin/pgrep -x "gamescope-wl" > /dev/null; then

          echo "Gamescope is running. Adjusting"

          if [[ "$1" == "hdr" ]]; then
            echo "Enabling HDR"
            is_hdr=1
          else
            echo "Disabling HDR"
            is_hdr=0
          fi
          ${pkgs.gamescope}/bin/gamescopectl hdr_enabled "$is_hdr"
          # Gamescope FPS limiter is buggy
          # ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $SUNSHINE_CLIENT_FPS
        else
          echo "gamescope is not running. Starting"
          ${pkgs.systemd}/bin/systemctl --user reset-failed
          ${pkgs.gamescope}/bin/gamescopectl shutdown 2> /dev/null || true
          ${pkgs.systemd}/bin/systemctl --user stop sunshine-steam.service 2> /dev/null || true
          ${pkgs.systemd}/bin/systemctl --user reset-failed
          sleep 1

          # exec env ENABLE_LAYER_MESA_ANTI_LAG=0 LFX=0 steam

          ${pkgs.systemd}/bin/systemd-run --user \
            --unit=sunshine-steam \
            --remain-after-exit \
            --setenv=GSC_HDR_MODESET="$([ "$is_hdr" = "1" ] && echo 1)" \
            --description="Launch Steam Gamescope detached in desktop session" \
            ${pkgs.bash}/bin/bash -c '
              exec gsc -e -- steam -console -gamepadui
            '
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

    # Needed for Sunshine DualSense input
    udev.extraRules = ''
      KERNEL=="uhid", MODE="0660", GROUP="input"
    '';
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
