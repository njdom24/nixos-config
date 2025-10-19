# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }: {
  imports =
    [
      inputs.chaotic.nixosModules.default
      ./gamescope.nix
    ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  	outputs.overlays.modifications
  ];

  # https://gitlab.freedesktop.org/drm/amd/-/issues/2516#note_1874760
  boot.kernelParams = [ "gpu_sched.sched_policy=0" ];

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
                fi
                echo "Attempting to start Steam on XWayland-Satellite"
                export DISPLAY=:1
                ${pkgs.xorg.xrdb}/bin/xrdb -merge <<< "Xft.dpi: 96"
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
  	  latencyflex-vulkan
  	  libstrangle # Better for some games with launchers, where MangoHud can crash
  	];

  	variables = {
  	  "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "0";
  	  #"MANGOHUD" = "1";
  	  "MESA_GIT" = lib.concatStringsSep ":" [
  	    "${pkgs.mesa_git}/share/vulkan/icd.d/radeon_icd.x86_64.json"
  	    "${pkgs.mesa32_git}/share/vulkan/icd.d/radeon_icd.i686.json"
  	  ];
  	};
  };

  # Sourced from https://github.com/Jovian-Experiments/Jovian-NixOS/blob/c40d2f31f92571bf341497884174a132829ef0fc/modules/steamos/sysctl.nix#L38
  boot.kernel.sysctl = {
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
}
