# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;

  gst_plugins = (with pkgs.gst_all_1; [
  	gstreamer
  	gst-plugins-base
	gst-plugins-good
	gst-plugins-bad
	gst-plugins-ugly
	gst-libav
	gst-vaapi
  ]);

in
{
  imports =
    [
      ../../desktops/sway
    ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.damino = {
    isNormalUser = true;
    description = "damino";
    extraGroups = [ 
    	"networkmanager"
    	"wheel"
    	"video"
    	"audio"
    	"render"
    	"input"
    	"kvm"
    ] ++ ifTheyExist [
    	"docker"
    	"libvirtd"
    	"plugdev"
    	"corectrl"
    	"adbusers"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      home-manager
      selectdefaultapplication
      mesa-demos
      vulkan-tools
      nvtopPackages.full
      rclone
      handbrake
      firefox
      vdhcoapp
      (chromium.override { enableWideVine = true; })
      kate
      kitty
      ffmpeg-full
      nautilus
      file-roller
      loupe
      gimp
      vlc
      libva-utils
      steam-run
      steamtinkerlaunch
      (if config.programs.steam.gamescopeSession.enable then gamescope-steam else null)
      samrewritten
      moonlight-qt
      unstable.lutris
      vkbasalt
      protontricks
      protonup-qt
      fastfetch
      zsh
      oh-my-zsh
      mission-center
      iwgtk
      fd
      btop
      killall
	  nix-index
	  pavucontrol
	  pulseaudio # Needed for pactl
	  remmina
	  filezilla
	  #gammastep
	  blueberry
	  warpinator
	  gnome-font-viewer
	  gnome-disk-utility
	  gnome-system-monitor
	  libnotify
	  xwaylandvideobridge
	  #discord
	  (discord.override {
	  	withOpenASAR = true; # If this breaks, set to false and re-run Discord. https://github.com/NixOS/nixpkgs/issues/208749
	  })
	  
	  #betterdiscord-installer

	  betterdiscordctl
	  vesktop
	  unstable.ludusavi
	  unstable.ryujinx
	  # citra-mk7 TODO: https://github.com/NixOS/nixpkgs/pull/348927
	  dolphin-emu
	  unstable.cemu
	  (unstable.melonDS.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
	  (retroarch.override {
	    cores = with unstable.libretro; [
	      mgba
	    ];
  	  })
	  jellyfin-media-player
	  xorg.xeyes
	  corefonts
	  vistafonts
	  vscode
    ];
  };

  nix = {
    settings = {
      auto-optimise-store = true;
  	};
  	gc = {
  	  automatic = true;
  	  dates = "weekly";
  	  options = "--delete-older-than 7d";
  	};
  };

  nixpkgs.config.input-fonts.acceptLicense = true;

  fonts.packages = with pkgs; [
  	fira-code
  	inter
  	input-fonts
  	noto-fonts
  	noto-fonts-cjk-sans
  	noto-fonts-emoji
  	nerdfonts
  ];

  qt = {
  	enable = true;
  	platformTheme = "qt5ct";
  };

  programs = {
	dconf.enable = true;
	#ssh.startAgent = true;
	seahorse.enable = true;
	ssh = {
	  enableAskPassword = true;
	  askPassword = pkgs.lib.mkForce "${pkgs.seahorse.out}/libexec/seahorse/ssh-askpass";
	};
  
    zsh.enable = true;

    adb.enable = true;

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
            if echo "$WAYLAND_DISPLAY" | ${pkgs.gnugrep}/bin/grep "gamescope" >/dev/null 2>&1; then
              # Launched through gamescope. Could enable after https://github.com/Supreeeme/extest/issues/11 or portal issue below
              echo "Disabling Extest"
            else
              # Needed until https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
              export LD_PRELOAD="$LD_PRELOAD:${pkgs.pkgsi686Linux.extest}/lib/libextest.so"
            fi
          fi
        '';
        # https://github.com/NixOS/nixpkgs/issues/271483
        extraLibraries = pkgs: [ pkgs.pkgsi686Linux.gperftools ]; 
      };

      extraPackages = with pkgs; [
        gamescope
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
      ] ++ gst_plugins;

      gamescopeSession = {
        enable = true;
        env = {
          WLR_RENDERER = "vulkan";
          STEAM_MULTIPLE_XWAYLANDS = "1";
        };
        args = [
          "-f"
          "--xwayland-count 2"
          "--mangoapp"
          "--adaptive-sync"
          "--expose-wayland"
        ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false; # Needed or gamescope fails within Steam
    };

    corectrl = {
      enable = true;
      package = pkgs.unstable.corectrl.overrideAttrs (finalAttrs: prevAttrs: {
      	qtWrapperArgs = ["--unset QT_QPA_PLATFORMTHEME"];
      });
      gpuOverclock.enable = true;	
    };

    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
	  	wlrobs
	  	obs-pipewire-audio-capture
	  	obs-vaapi
	  	obs-gstreamer
	  ];
    };

    noisetorch.enable = true;
    virt-manager.enable = true;
  };

  virtualisation = {
  	libvirtd.enable = true;
  	docker.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
    	enable = true;
    	powerOnBoot = true;
    	# package = pkgs.legacy.bluez;
    	settings = {
    	  General = {
    	  	UserspaceHID = "true";
    	  };
    	};
    };
  	graphics = {
  		enable32Bit = true; # Enables support for 32bit libs that steam uses
  		extraPackages = with pkgs; [ vaapiVdpau libvdpau-va-gl libva libva-utils vulkan-loader vulkan-validation-layers vulkan-extension-layer ];
  		extraPackages32 = with pkgs; [ ];
  	};
  	#nvidia = {
  	  # Modesetting is required.
      #modesetting.enable = true;
  	#};
  	# TODO: https://github.com/NixOS/nixpkgs/issues/357693
  	#xpadneo.enable = true; 
  	xone.enable = true;
  	#openrazer.enable = true;
  };

  fonts = {
  	fontconfig = {
  	  antialias = true;
  	  hinting.enable = true;
  	  hinting.autohint = true;	
  	};
  };

  services = {
    displayManager.sddm = {
  	  enable = true;
  	  theme = "Elegant";
  	  settings = {
  	  	Theme.CursorTheme = "XCursor-Pro-Dark";
  	  };

  	  wayland = {
  	    enable = true;
  	    compositorCommand =
  	      let
  	        monitorQuery = pkgs.writeShellScript "monitor-query" ''
              #!/usr/bin/env bash

              # Define your list of preferred device names (or partial names) in order of priority
              PREFERRED_DEVICES=("Acer Technologies VG271U" "Samsung Electric Company LC27T55") # Replace with actual display names or partial names

              # Function to get all connected displays with their descriptions
              get_connected_displays() {
                  ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | .name + " " + (.make // "") + " " + (.model // "")'
              }

              # Retrieve the list of connected displays with their descriptions
              CONNECTED_DISPLAYS=$(get_connected_displays)

              # Filter out displays containing "HEADLESS"
              CONNECTED_DISPLAYS=$(echo "$CONNECTED_DISPLAYS" | ${pkgs.gnugrep}/bin/grep -v "HEADLESS")
              echo "$CONNECTED_DISPLAYS"

              # Initialize PRIMARY_DISPLAY as empty
              PRIMARY_DISPLAY=""

              # Iterate through the preferred devices list and select the first connected display matching a device name
              echo "Pref: ''\${PREFERRED_DEVICES[@]}"
              for device_name in "''\${PREFERRED_DEVICES[@]}"; do
				  echo "DEVICE: $device_name"
                  if echo "$CONNECTED_DISPLAYS" | ${pkgs.gnugrep}/bin/grep -q "$device_name"; then
                      PRIMARY_DISPLAY=$(echo "$CONNECTED_DISPLAYS" | ${pkgs.gnugrep}/bin/grep "$device_name" | ${pkgs.gawk}/bin/awk '{print $1}')
                      echo "Preferred monitor '$device_name' found: $PRIMARY_DISPLAY"
                      break  # Exit the loop once a match is found
                  fi
              done
              
              # If no preferred device is connected, default to the first connected display
              if [[ -z "$PRIMARY_DISPLAY" && -n "$CONNECTED_DISPLAYS" ]]; then
                  PRIMARY_DISPLAY=$(echo "$CONNECTED_DISPLAYS" | head -n 1 | ${pkgs.gawk}/bin/awk '{print $1}')
                  echo "No preferred monitor found; defaulting to first connected display: $PRIMARY_DISPLAY"
              fi

              # Export the primary display as an environment variable if a display was found
              if [[ -n "$PRIMARY_DISPLAY" ]]; then
                  export PRIMARY_DISPLAY
                  echo "SWAYSOCK: $SWAYSOCK"
                  echo "Primary display set to: $PRIMARY_DISPLAY"

                  # Enable the primary display if it's disabled
                  ${pkgs.sway}/bin/swaymsg output "*" disable
                  ${pkgs.sway}/bin/swaymsg output "$PRIMARY_DISPLAY" enable
              else
                  echo "No connected displays found."
              fi
  	        '';
            swayCfg = pkgs.writeText "sway.conf" ''
              output "*" {
                bg #000000 solid_color
              }
              exec ${monitorQuery}
              exec ${pkgs.sway}/bin/swaymsg create_output "HEADLESS-1"
              exec ${pkgs.bash}/bin/bash -c "${pkgs.wayvnc}/bin/wayvnc 127.0.0.1 --log-level=info > /tmp/wayvnc_login; sleep 10 && rm -f /tmp/wayvnc_login"
            '';
          in
          "/usr/bin/env WLR_BACKENDS=drm,headless,libinput ${pkgs.sway}/bin/sway -c ${swayCfg}";
  	  };

  	  # https://github.com/NixOS/nixpkgs/issues/292761
  	  package = pkgs.lib.mkForce pkgs.libsForQt5.sddm;
  	  extraPackages = pkgs.lib.mkForce [];
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;	
    };
  	openssh = {
  	  enable = true;
  	  settings = {
  	    X11Forwarding = true;
  	  	PasswordAuthentication = true;
  	  };
 	};
 	ananicy = {
 	  enable = true;
 	  package = pkgs.ananicy-cpp;
 	  rulesProvider = pkgs.ananicy-rules-cachyos;
 	};
 	gnome.gnome-keyring.enable = true;
 	gvfs.enable = true;
 	fstrim.enable = true;
  };

  security = {
    rtkit.enable = true;
    pam = {
      enableEcryptfs = true;
      services.gdm.enableGnomeKeyring = true;
      services.sddm.enableGnomeKeyring = true;	
    };
  };

  boot = {
  	kernelModules = [ "ecryptfs" ];
  	kernel.sysctl."kernel.sysrq" = 1;
  	tmp = {
      useTmpfs = true;
      tmpfsSize = "80%";
    };
  };

  # OOM configuration: https://discourse.nixos.org/t/nix-build-ate-my-ram/35752
  systemd = {
    # Create a separate slice for nix-daemon that is
    # memory-managed by the userspace systemd-oomd killer
    slices."nix-daemon".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
    services."nix-daemon".serviceConfig.Slice = "nix-daemon.slice";

    # If a kernel-level OOM event does occur anyway,
    # strongly prefer killing nix-daemon child processes
    services."nix-daemon".serviceConfig.OOMScoreAdjust = 1000;
  };

  environment = {
  	systemPackages = with pkgs; [
  	  lsof
  	  file
  	  wget
  	  sshfs
  	  libarchive
  	  p7zip
  	  unzip
  	  zip
  	  duperemove
  	  xdotool
  	  ecryptfs
  	  ethtool
  	  gtk3
  	  pcmanfm
  	  #wineWowPackages.stagingFull
  	  wineWowPackages.waylandFull
  	  winetricks
  	  elegant-sddm
  	  xcursor-pro
  	  pciutils
  	  libgcc
  	  bison
  	  flex
  	  freetype
  	  OVMFFull
  	  python3
  	  distrobox
  	  waypipe
  	] ++ gst_plugins;

  	variables = {
  	  "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "1";
  	  #"TZ" = "${config.time.timeZone}";
  	  #"MANGOHUD" = "1";
  	  "GST_PLUGIN_SYSTEM_PATH_1_0" = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gst_plugins;
  	};
  	extraInit = "source ${config.users.users.damino.home}/.nix-profile/etc/profile.d/hm-session-vars.sh";
  };

  # If home-manager is managed by system:
  #home-manager.users.damino = import ../../../../home/damino/${config.networking.hostName}.nix;

  # Warpinator
  networking.firewall = {
  	allowedTCPPorts = [
  	    42000
  	    42001
  	];
  	allowedUDPPorts = [
  	    5353
 	];
  };
}
