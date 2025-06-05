# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }: {
  imports =
    [
      inputs.chaotic.nixosModules.default
    ] ++ (builtins.attrValues outputs.nixosModules);

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
        
        extraProfile = ''
          # https://github.com/NixOS/nixpkgs/issues/279893
          unset TZ
          if [ -n "$SWAYSOCK" ]; then
            if echo "$WAYLAND_DISPLAY" | ${pkgs.gnugrep}/bin/grep "gamescope" >/dev/null 2>&1 || pgrep "gamescope" > /dev/null; then
              # Launched through gamescope. Could enable after https://github.com/Supreeeme/extest/issues/11 or portal issue below
              echo "Disabling Extest"
            else
              # Needed until https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
              export LD_PRELOAD="$LD_PRELOAD:${pkgs.pkgsi686Linux.extest}/lib/libextest.so"
              echo "Enabling Extest"
            fi
          fi
        '';
        # https://github.com/NixOS/nixpkgs/issues/271483
        extraLibraries = pkgs: [ pkgs.pkgsi686Linux.gperftools ];
      };

      extraPackages = with pkgs; [
        gamescope
        gamescope-wsi
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
        gamescope-wsi
        vulkan-loader
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
        PROTON_ENABLE_AMD_AGS = "1";
      };
      args = [
        "-f"
        "--xwayland-count 2"
        #"--backend sdl" # https://github.com/ValveSoftware/gamescope/issues/1622 and causes stutter (maybe https://github.com/ValveSoftware/gamescope/issues/995)
        "--hdr-enabled"
        "--adaptive-sync"
        "-r 360" # Default that is a multiple of 120 and 180
        #"--mangoapp"
      ];
    };

    corectrl = {
      enable = true;
      package = pkgs.unstable.corectrl.overrideAttrs (finalAttrs: prevAttrs: {
      	qtWrapperArgs = ["--unset QT_QPA_PLATFORMTHEME"];
      });
      gpuOverclock.enable = true;	
    };
  };

  hardware = {
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
 	    {
 	      name = "sway";
 	      nice = -20;
 	    }
 	    {
 	      name = ".sway-wrapped";
 	      nice = -20;
 	    }
 	    {
 	      name = "gamescope";
 	      type = "LowLatency_RT";
 	    }
 	    {
 	      name = "gamescope-wl";
 	      type = "LowLatency_RT";
 	    }
 	    {
 	      name = "sunshine";
 	      type = "Player-Video";
 	    }
 	  ];
 	};
  };

  environment = {
  	systemPackages = with pkgs; [
  	  steam-run
  	  steamtinkerlaunch
  	  # https://github.com/ValveSoftware/steam-for-linux/issues/11479
  	  # cd to /tmp to somehow avoid stutters with VRR
  	  (if config.programs.steam.gamescopeSession.enable then (pkgs.writeTextDir "share/applications/steam-gamescope.desktop" ''
  	    [Desktop Entry]
  	    Name=Steam (Gamescope)
  	    Comment=Launch Steam via Gamescope (Embedded)
  	    Exec=/usr/bin/env bash -c "cd /tmp && gamescope -e -- steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu"
  	    Icon=steam
  	    Type=Application
  	    Categories=Game;
  	  '') else null)
  	  (if config.programs.gamescope.enable then gamescope-wsi else null)
  	  samrewritten
  	  moonlight-qt
  	  unstable.lutris
  	  unstable.xivlauncher
  	  vkbasalt
  	  protontricks
  	  protonup-qt
	  unstable.ludusavi
	  unstable.ryujinx
	  # citra-mk7 TODO: https://github.com/NixOS/nixpkgs/pull/348927
	  dolphin-emu
	  unstable.cemu
	  (unstable.melonDS.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
      (retroarch.withCores (cores: with cores; [
        mgba
      ]))
  	  #wineWowPackages.stagingFull
  	  wineWowPackages.waylandFull
  	  winetricks
  	  lact # TODO: Should become a module in 25.05
  	  latencyflex-vulkan
  	  vulkan-hdr-layer-kwin6
  	];

  	variables = {
  	  "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "0";
  	  #"MANGOHUD" = "1";
  	};
  };

  systemd.packages = with pkgs; [ lact ];
  systemd.services.lactd.wantedBy = ["multi-user.target"];
}
