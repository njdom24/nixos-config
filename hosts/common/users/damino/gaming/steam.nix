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
    steam = {
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
