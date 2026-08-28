# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }: {
  imports =
    [
      ./steam.nix
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
    enable = lib.mkDefault false;
    global = lib.mkDefault false;
  };

  programs = {
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

    lact.enable = true;

 	ananicy = {
 	  enable = true;
 	  package = pkgs.ananicy-cpp;
 	  rulesProvider = pkgs.ananicy-rules-cachyos;
      # Breaks login 50% of the time, possibly since Sway run under sddm?
      extraTypes = [
        {
          type = "LowLatency_RT";
          #sched = "rr";
          nice = -20;
          ioclass = "best-effort";
        }
      ];
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
 	    {
 	      name = "wlr-hdr-cal";
 	      type = "BG_CPUIO";
 	    }
 	    {
 	      name = "noctalia";
 	      type = "service";
 	    }
        {
          name = "jay";
          type = "LowLatency_RT";
        }
 	  ];
 	};
  };
  # Soemtimes would start too early and enter a bad state
  systemd.services.ananicy-cpp.after = lib.mkAfter [ "multi-user.target" ];

  environment = {
  	systemPackages = with pkgs; [
  	  moonlight-qt
      faugus-launcher
  	  unstable.xivlauncher
  	  vkbasalt
	  unstable.ludusavi
	  unstable.ryubing
	  dolphin-emu
	  unstable.cemu
	  rpcs3
	  (unstable.melonds.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
	  unstable.azahar
      (retroarch.withCores (cores: with cores; [
        mgba
      ]))
      wineWow64Packages.waylandFull
  	  winetricks
  	  libstrangle # Better for some games with launchers, where MangoHud can crash
  	  latencyflex
      low-latency-layer
  	];

    variables = {
      "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "0";
      #"MANGOHUD" = "1";
      #"ENABLE_LAYER_MESA_ANTI_LAG" = "1"; # Auto-disabled with FSR4_UPGRADE=1
      "AMD_USERQ" = "1"; # Added in Mesa 25.0. May reduce stutter in FG
    };
  };

  boot = {
    kernelModules = [ "ntsync" ];
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
