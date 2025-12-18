# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }: {
  imports =
    [
      ./gamescope.nix
      outputs.nixosModules.mesa-git
    ];

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  	outputs.overlays.modifications
  ];

  mesa-git = {
    enable = false;
    global = false;
  };

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
        (writeScriptBin "steamos-polkit-helpers/steamos-update" ''
          #!${pkgs.stdenv.shell}
          exit 7
        '')
      ];

      extraCompatPackages = with pkgs; [
        vulkan-loader
      ];
    };

    gpu-screen-recorder.enable = true;
  };

  hardware = {
    amdgpu.overdrive.enable = true;
  	graphics = {
  	  enable32Bit = true; # Enables support for 32bit libs that steam uses
  	};
  	# TODO: https://github.com/NixOS/nixpkgs/issues/357693
  	#xpadneo.enable = true; 
  	#xone.enable = true;
  	#openrazer.enable = true;
  	bluetooth.settings.General.FastConnectable = true; # May help with gamepad disconnections
  };

  services = {
    udev.extraRules = ''
      ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="*Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="Sunshine*Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

    cpupower-gui.enable = true;
    lact.enable = true;

 	ananicy = {
 	  enable = true;
 	  package = pkgs.ananicy-cpp;
 	  rulesProvider = pkgs.ananicy-rules-cachyos;
      # Breaks login 50% of the time, possibly since Sway run under sddm?
 	  #extraTypes = [
 	  #  {
 	  #    type = "LowLatency_RT";
 	  #    sched = "rr";
 	  #  }
 	  #];
 	  extraRules = [
 	    # -12: https://github.com/CachyOS/ananicy-rules/blob/master/00-default/DEs-and-WMs/sway.rules
 	    #{
 	    #  name = "sway";
 	    #  nice = -20;
 	    #}
 	    # 
 	    # No longer needed: https://github.com/NixOS/nixpkgs/pull/319634
 	    #{
 	    #  name = ".sway-wrapped";
 	    #  nice = -20;
 	    #}
 	    # -20: https://github.com/CachyOS/ananicy-rules/blob/master/00-default/games/gamescope.rules
 	    #{
 	    #  name = "gamescope";
 	    #  type = "LowLatency_RT";
 	    #}
 	    #{
 	    #  name = "gamescope-wl";
 	    #  type = "LowLatency_RT";
 	    #}
 	    {
 	      name = "sunshine";
 	      type = "LowLatency_RT";
 	    }
 	  ];
 	};
  };

  systemd.services.bluetooth-watcher = {
    description = "Watch bluetooth.service logs for fatal errors";

    partOf   = [ "bluetooth.service" ];
    after    = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";

      ExecStart = pkgs.writeShellScript "bluetooth-watcher" ''
        PATTERN='hidp_report_req_timeout|Set device flags return status: Invalid Parameters'
        WINDOW=10        # seconds
        THRESHOLD=2      # number of messages
        SERVICE=bluetooth.service

        # Remember when we started, so we ignore earlier logs
        START_TS=$(date +%s)

        echo "[bluetooth-watcher] Started at timestamp $START_TS."

        while true; do
          NOW=$(date +%s)
          SINCE=$((NOW - WINDOW))

          # Get messages since the watcher started
          ${pkgs.systemd}/bin/journalctl -u "$SERVICE" \
            --since "@$(( START_TS > SINCE ? START_TS : SINCE ))" \
            --no-pager -o short-unix |
            ${pkgs.gnugrep}/bin/grep -E "$PATTERN" |
              ${pkgs.coreutils}/bin/wc -l | {
                read COUNT
                if [[ "$COUNT" -ge "$THRESHOLD" ]]; then
                  echo "[bluetooth-watcher] Detected $COUNT messages — restarting bluetooth.service"
                  ${pkgs.systemd}/bin/systemctl restart "$SERVICE"
                  # After restart, advance START_TS so old logs don’t re-trigger
                  START_TS=$(date +%s)
                fi
              }

            sleep 2
        done
      '';
    };
  };

  environment = {
  	systemPackages = with pkgs; [
  	  steam-run
  	  steamtinkerlaunch
  	  samrewritten
  	  sgdboop
  	  moonlight-qt
  	  unstable.lutris
  	  unstable.xivlauncher
  	  vkbasalt
  	  protontricks
  	  protonplus
	  unstable.ludusavi
	  unstable.ryubing
	  # citra-mk7 TODO: https://github.com/NixOS/nixpkgs/pull/348927
	  dolphin-emu
	  unstable.cemu
	  # Fixes RPCN UI freeze
	  unstable.rpcs3
	  #(unstable.rpcs3.overrideAttrs (prevAttrs: {
	  #  preFixup = (prevAttrs.preFixup) + ''
	  #    qtWrapperArgs+=(--set QT_QPA_PLATFORM xcb)
	  #  '';
	  #}))
	  (unstable.melonDS.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
	  unstable.azahar
      (retroarch.withCores (cores: with cores; [
        mgba
      ]))
  	  #wineWowPackages.stagingFull
  	  wineWowPackages.waylandFull
  	  winetricks
  	  libstrangle # Better for some games with launchers, where MangoHud can crash
  	];

  	variables = {
  	  "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "0";
  	  #"MANGOHUD" = "1";
  	};
  };

  boot = {
    # https://gitlab.freedesktop.org/drm/amd/-/issues/2516#note_1874760
    kernelParams = [ "gpu_sched.sched_policy=0" "split_lock_detect=off" ];
    kernel.sysctl = {
      "kernel.split_lock_mitigate" = lib.mkDefault 0;
      # > This is required due to some games being unable to reuse their TCP ports
      # > if they're killed and restarted quickly - the default timeout is too large.
      #  - https://github.com/Jovian-Experiments/steamos-customizations-jupiter/commit/4c7b67cc5553ef6c15d2540a08a737019fc3cdf1
      "net.ipv4.tcp_fin_timeout" = lib.mkDefault 5;
      # > USE MAX_INT - MAPCOUNT_ELF_CORE_MARGIN.
      # > see comment in include/linux/mm.h in the kernel tree.
      #  - https://github.com/Jovian-Experiments/steamos-customizations-jupiter/commit/e21954bb4743635a9c53016def5158469fa6d7a8
      "vm.max_map_count" = lib.mkForce 2147483642;
    }; 
  };
}
