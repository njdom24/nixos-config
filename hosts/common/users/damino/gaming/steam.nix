# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }: {
  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  	outputs.overlays.modifications
  ];

  programs = {
    steam = let
    steam-hdr-screenshot-watcher = pkgs.writeShellScript "steam-hdr-screenshot-watcher.sh" ''
      #!/usr/bin/env bash
      set -m

      LOG="$HOME/.steam/steam/logs/gameprocess_log.txt"
      USER_LOG="$HOME/.steam/steam/logs/connection_log.txt"
      STEAM_USERID=$(${pkgs.gnugrep}/bin/grep -Po '\[U:1:\K[0-9]+' "$USER_LOG" | tail -n1)

      SCREENSHOT_EXTDIR="$HOME/Documents/HDR Screenshots" # Must be manually set in Steam settings to create AVIF files
      LATEST_APPID=""
      CURRENT_WATCH_PID=""

      if [[ ! -d "$SCREENSHOT_EXTDIR" ]]; then
        echo "Directory does not exist"
        exit 1
      fi

      cleanup() {
        echo "Cleaning up…"
        ${pkgs.systemd}/bin/systemctl --user stop steam-screenshot-watcher
        ${pkgs.systemd}/bin/systemctl --user reset-failed steam-screenshot-watcher

        trap - INT TERM
        kill -- -$$ 2>/dev/null
        exit 0
      }

      trap cleanup INT TERM

      STEAM_PID=$(pgrep -x steam | head -n1)
      if [[ -z "$STEAM_PID" ]]; then
        echo "Steam is not running."
      fi

      # Watch steam in background
      (
        while ! ${pkgs.procps}/bin/pgrep -x "steam" > /dev/null; do
          sleep 2
          echo "Waiting for Steam to start"
        done
        STEAM_PID=$(${pkgs.procps}/bin/pgrep -x steam | head -n1)
        echo "Monitoring Steam process PID $STEAM_PID"
        sleep 30

        while kill -0 "$STEAM_PID" 2>/dev/null; do
          sleep 30
        done
        echo "Steam exited — cleaning up everything"
        cleanup
      ) &
      STEAM_WATCHER_PID=$!

      # Function to monitor the screenshot directory for an AppID
      monitor_screenshots() {
        set -m
        local userid="$1"
        local appid="$2"
        SCREENSHOT_BASE="$HOME/.local/share/Steam/userdata/$userid/760/remote"
        SCREENSHOT_EXTDIR="$HOME/Documents/HDR Screenshots"
        local dir="$SCREENSHOT_BASE/$appid/screenshots"

        # Make sure the directory exists
        mkdir -p "$dir"

        echo "Monitoring screenshots for AppID $appid in $dir"

        # Start watching with inotifywait
        ${pkgs.inotify-tools}/bin/inotifywait -m -e create "$dir" --format "%f" |
        while read -r newfile; do
          if [[ "$newfile" != *.jpg ]] && [[ "$newfile" != *.jpeg ]]; then
            continue
          fi
          echo "New screenshot detected for AppID $appid: $newfile"
          fullpath="$dir/$newfile"
          # Compute the AVIF filename
          # "''$()"
          base="''${newfile%.*}"           # strip extension
          avif_file="$SCREENSHOT_EXTDIR/$appid""_$base.avif"
          (
            sleep 1
            if [[ -f "$avif_file" ]]; then
              echo "HDR screenshot detected at DIR $dir FILE $newfile"
              # Increase brightness and contrast. Steam HDR screenshots are too dim
              #${pkgs.imagemagick}/bin/magick "$dir/$newfile" -brightness-contrast 5x10 "$dir/$newfile"
              # Tonemap HDR screenshot to SDR
              output="$XDG_RUNTIME_DIR/tonemapped_screenshot_$base".jpg
              #${pkgs.imagemagick}/bin/magick "$avif_file" -clamp -sigmoidal-contrast 14x40% -level 0%,100%,1.35 -colorspace sRGB "$output"
              #${pkgs.imagemagick}/bin/magick "$avif_file" -clamp -sigmoidal-contrast 16x52% -level 0%,100%,2.2 -colorspace sRGB "$output"
              #${pkgs.imagemagick}/bin/magick "$avif_file" -clamp -sigmoidal-contrast 14x52% -level 0%,100%,2.2 -evaluate multiply 1.0 -modulate 100,120,100 -colorspace sRGB "$output"

              ${pkgs.imagemagick}/bin/magick "$fullpath" -brightness-contrast 8x16 "$output" # Works, but has banding

              # Compress to match original size
              ref_size=$(stat -c%s "$dir/$newfile")
              echo "Reference size: $ref_size bytes"
              size_kb=$(( ref_size / 1024 ))
              # "''$()"
              ${pkgs.jpegoptim}/bin/jpegoptim --size=''${size_kb}k "$output"
              cp "$output" "$dir/$newfile"

              # Repeat for thumbnail
              thumbnail="$dir/thumbnails/$newfile"
              output_thumbnail="$XDG_RUNTIME_DIR/tonemapped_thumbnail_$base".jpg

              # Compress to match original size
              ref_size=$(stat -c%s "$thumbnail")
              echo "Reference size: $ref_size bytes"
              size_kb=$(( ref_size / 1024 ))
              read tw th < <(${pkgs.imagemagick}/bin/magick identify -format "%w %h" "$thumbnail")
              ${pkgs.imagemagick}/bin/magick "$output" -resize "''${tw}x''${th}!" "$output_thumbnail"
              ${pkgs.jpegoptim}/bin/jpegoptim --size=''${size_kb}k "$output_thumbnail"
              mv "$output_thumbnail" "$thumbnail"
              rm "$output"
              # "''$()"
            else
              echo "No HDR counterpart for $newfile at $avif_file"
            fi
            #rm "$SCREENSHOT_EXTDIR/$base.png" 2> /dev/null || true # Remove unnecessary file
          ) &
        done
      }
      export -f monitor_screenshots

      echo "Monitoring screenshots for Steam user: $STEAM_USERID"

      # Watch the Steam log for new AppIDs
      #tail -Fn0 "$LOG" | while read -r line; do
      exec 3< <(tail -Fn0 "$LOG")
      while read -r line <&3; do
        if [[ $line =~ AppID\ ([0-9]+)\ adding\ PID ]]; then
          # "''$()"
          NEW_APPID="''${BASH_REMATCH[1]}"

          # If AppID changed, stop previous monitor and start a new one
          if [[ "$NEW_APPID" != "$LATEST_APPID" ]]; then
            echo "AppID changed: $LATEST_APPID -> $NEW_APPID"

            # Kill previous screenshot monitor
            if [[ -n "$CURRENT_WATCH_PID" ]]; then
              kill -- "$CURRENT_WATCH_PID" 2>/dev/null
            fi

            # Start new screenshot monitor in background
            #monitor_screenshots "$NEW_APPID" &
            setsid bash -c 'monitor_screenshots "$0" "$1"' "$STEAM_USERID" "$NEW_APPID" &
            CURRENT_WATCH_PID=$!

            LATEST_APPID="$NEW_APPID"
          fi
        fi
      done
    '';
    in {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server	
	  #extest.enable = true; # Breaks when Steam is run through gamescope. Alternatively needs https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
      package = pkgs.steam.override {
        # https://github.com/NixOS/nixpkgs/issues/279893#issuecomment-3066010773
        #extraEnv = {
        #  TZDIR = "/usr/share/zoneinfo";
        #};
        privateTmp = false; # Fixes gamescope HDR screenshots (they go in /tmp)
        extraProfile = ''
          # https://github.com/NixOS/nixpkgs/issues/279893
          unset TZ
          if [ -n "$SWAYSOCK" ] || [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
            if [ "$XDG_CURRENT_DESKTOP" = "gamescope" ]; then
              # Launched through gamescope. Could enable after https://github.com/Supreeeme/extest/issues/11 or portal issue below
              echo "Disabling Extest"
            else
              # Work around Sway's refusal to unscale XWayland: https://github.com/swaywm/sway/issues/2966
              if [[ "$XDG_CURRENT_DESKTOP" = "sway" ]]; then
                if ! ${pkgs.procps}/bin/pgrep -f xwayland-satellite >/dev/null; then
                  echo "xwayland-satellite is not running. Starting"
                  ${pkgs.xwayland-satellite}/bin/xwayland-satellite &
                  sleep 1
                  echo "Attempting to start Steam on XWayland-Satellite"
                  export DISPLAY=:1
                  ${pkgs.xorg.xrdb}/bin/xrdb -merge <<< "Xft.dpi: 96"
                fi
              fi
              # Needed until https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
              # and/or https://github.com/hyprwm/Hyprland/pull/7919
              export LD_PRELOAD="$LD_PRELOAD:${pkgs.pkgsi686Linux.extest}/lib/libextest.so"
              echo "Enabling Extest"
            fi
          fi

          status="$(${pkgs.systemd}/bin/systemctl --user is-active steam-screenshot-watcher.service)"
          if [[ "$status" != "active" ]]; then
            ${pkgs.systemd}/bin/systemctl --user reset-failed steam-screenshot-watcher
            ${pkgs.systemd}/bin/systemd-run --user --unit=steam-screenshot-watcher --description="Monitor Steam HDR screenshots to increase brightness" ${steam-hdr-screenshot-watcher}
          fi
        '';
        # https://github.com/NixOS/nixpkgs/issues/271483
        extraLibraries = pkgs: [ pkgs.pkgsi686Linux.gperftools ];
      };

      extraPackages = with pkgs; [
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
        # Where gamescope-session looks for "Exit to Desktop" when -steamos3 is provided
        (writeShellScriptBin "steamos-session-select" ''
          /usr/bin/env steam -shutdown
        '')
        (writeScriptBin "steamos-select-branch" ''
          #!${pkgs.stdenv.shell}
          exit 7
        '')
        (writeScriptBin "steamos-polkit-helpers/steamos-update" ''
          #!${pkgs.stdenv.shell}
          exit 7
        '')
        (writeScriptBin "steamos-polkit-helpers/jupiter-dock-updater" ''
          #!${pkgs.stdenv.shell}
          exit 7
        '')
      ];

      extraCompatPackages = with pkgs; [
        vulkan-loader
      ];
    };
  };

  environment = {
  	systemPackages = with pkgs; [
  	  steam-run
  	  steamtinkerlaunch
  	  samrewritten
  	  sgdboop
  	  protontricks
  	  protonplus
  	];
  };
}
