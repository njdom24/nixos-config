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
      ./gaming.nix
    ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
    outputs.overlays.stable-packages
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
    	"i2c"
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
      kdePackages.kate
      kitty
      ffmpeg-full
      nautilus
      file-roller
      loupe
      gimp
      vlc
      libva-utils
      steam-run
      fastfetch
      zsh
      oh-my-zsh
      mission-center
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
	  kdePackages.xwaylandvideobridge
	  (discord.override {
	  	withOpenASAR = true; # If this breaks, set to false and re-run Discord. https://github.com/NixOS/nixpkgs/issues/208749
	  })
	  #betterdiscord-installer
	  betterdiscordctl
	  vesktop
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
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  qt = {
  	enable = true;
  	platformTheme = "qt5ct";
  };

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      # dns = "systemd-resolved";
      wifi.backend = "iwd";
    };
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
  	  extraPackages = with pkgs; [ vaapiVdpau libvdpau-va-gl libva libva-utils vulkan-loader vulkan-validation-layers vulkan-extension-layer ];
  	  extraPackages32 = with pkgs; [ ];
  	};
  	#nvidia = {
  	  # Modesetting is required.
      #modesetting.enable = true;
  	#};
  	i2c.enable = true;
  };

  fonts = {
  	fontconfig = {
  	  antialias = true;
  	  hinting.enable = true;
  	  hinting.autohint = true;	
  	};
  };

  services = {
    power-profiles-daemon.enable = true;
    fwupd.enable = true;

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
  	        settingsFormat = pkgs.formats.keyValue { };
  	        sunshineCfg = settingsFormat.generate "sunshine.conf" config.services.sunshine.settings;
  	        monitorQuery = pkgs.writeShellScript "monitor-query" ''
              #!/usr/bin/env bash

              ${pkgs.sway}/bin/swaymsg create_output "HEADLESS-1"
              ${pkgs.sway}/bin/swaymsg output "HEADLESS-1" pos 0 0

              # Define your list of preferred device names (or partial names) in order of priority
              PREFERRED_DEVICES=("Xiaomi Corporation Mi Monitor" "Acer Technologies VG271U" "Samsung Electric Company LC27T55") # Replace with actual display names or partial names

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
                  ${pkgs.sway}/bin/swaymsg output "$PRIMARY_DISPLAY" enable pos 0 0
              else
                  echo "No connected displays found."
              fi
  	        '';
            swayCfg = pkgs.writeText "sway.conf" ''
              output "*" {
                bg #000000 solid_color
              }
              exec ${monitorQuery}
              exec ${pkgs.bash}/bin/bash -c "sleep 5 && ${pkgs.wayvnc}/bin/wayvnc 127.0.0.1 --log-level=info > /tmp/wayvnc_login; ${pkgs.procps}/bin/kill `${pkgs.procps}/bin/pgrep sunshine`; sleep 10 && rm -f /tmp/wayvnc_login"
              exec ${pkgs.bash}/bin/bash -c "${pkgs.procps}/bin/kill `${pkgs.procps}/bin/pgrep sunshine`"
              exec ${pkgs.bash}/bin/bash -c "sleep 5 && ${pkgs.sunshine}/bin/sunshine ${sunshineCfg} > /tmp/sunshine_login"
            '';
          in
          "/usr/bin/env WLR_BACKENDS=drm,headless,libinput WLR_RENDERER=vulkan ${pkgs.sway}/bin/sway -c ${swayCfg} --unsupported-gpu";
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
 	fail2ban.enable = true;

 	udev = {
 	  extraRules = ''
 	    #ACTION=="add", SUBSYSTEM=="i2c-dev", ATTR{name}=="AMDGPU DM*", TAG+="ddcci", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
 	    #ACTION=="add", SUBSYSTEM=="i2c-dev", ATTR{name}=="DPMST", TAG+="ddcci", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
 	    #ACTION=="add", SUBSYSTEM=="i2c-dev", ATTR{name}=="NVIDIA i2c adapter*", TAG+="ddcci", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
 	    #ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="ddcci*", RUN+="${pkgs.coreutils-full}/bin/chgrp video /sys/class/backlight/%k/brightness"
 	    #ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="ddcci*", RUN+="${pkgs.coreutils-full}/bin/chmod a+w /sys/class/backlight/%k/brightness"
 	  '';
 	  packages = [
 	    (lib.optionals config.services.sunshine.enable (pkgs.writeTextFile {
 	      name = "60-sunshine-extra.rules";
 	      text = ''KERNEL=="uhid", TAG+="uaccess"'';
 	      destination = "/etc/udev/rules.d/60-sunshine-extra.rules";
 	    }))
 	  ];
 	};

 	gnome.gnome-keyring.enable = true;
 	gvfs.enable = true;
 	fstrim.enable = true;
  };

  security = {
    rtkit.enable = true;
    pam = {
      services.gdm.enableGnomeKeyring = true;
      services.sddm.enableGnomeKeyring = true;	
    };
  };

  boot = {
  	# kernelModules = lib.mkAfter [ "ddcci_backlight" ];
  	#extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  	kernel.sysctl = {
  	  "kernel.sysrq" = 1;
  	  "kernel.panic" = 30;
  	};
  	tmp = {
      useTmpfs = true;
      tmpfsSize = "80%";
    };
  };

  # OOM configuration: https://discourse.nixos.org/t/nix-build-ate-my-ram/35752
  systemd = {
    services.power-profiles-daemon.wantedBy = [ "multi-user.target" ];
    watchdog.runtimeTime = "30s";
    # Create a separate slice for nix-daemon that is
    # memory-managed by the userspace systemd-oomd killer
    slices."nix-daemon".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
    services."nix-daemon".serviceConfig.Slice = "nix-daemon.slice";

    services."systemd-journald".serviceConfig = {
      TimeoutStartSec = "10s";
      TimeoutStopSec = "10s";
    };

    # If a kernel-level OOM event does occur anyway,
    # strongly prefer killing nix-daemon child processes
    services."nix-daemon".serviceConfig.OOMScoreAdjust = 1000;
    services."ddcci@" = {
        scriptArgs = "%i";
        script = ''
          echo Trying to attach ddcci to $1
          lockfile="/tmp/ddcutil.lock"
          exec 200>"$lockfile"
          id=$(echo $1 | cut -d "-" -f 2)
          counter=5
          while [ $counter -gt 0 ]; do
            if timeout 10s flock 200; then
            sleep 0.1
            if ${pkgs.ddcutil}/bin/ddcutil getvcp 10 -b $id; then
              echo ddcci 0x37 > /sys/bus/i2c/devices/$1/new_device
              echo Successfully attached ddcci to $1
              break
            fi
            fi
            sleep 5
            counter=$((counter - 1))
          done
        '';
        serviceConfig.Type = "oneshot";
      };
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
  	  ethtool
  	  networkmanagerapplet
  	  gtk3
  	  pcmanfm
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
  	  ddcutil
  	  gnome-firmware
  	] ++ gst_plugins;

  	variables = {
  	  #"TZ" = "${config.time.timeZone}";
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
