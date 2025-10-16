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
  imports = [
    ../../desktops/sway
    ./gaming
  ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
    outputs.overlays.stable-packages
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  ];

  #nixpkgs.config.permittedInsecurePackages = [
  #  "qtwebengine-5.15.19" # For jellyfin-media-player: https://github.com/NixOS/nixpkgs/issues/437865
  #];

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
      (chromium.override { enableWideVine = false; })
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
	  	withVencord = true;
	  })
	  #betterdiscord-installer
	  betterdiscordctl
	  vesktop
	  #jellyfin-media-player
	  kdePackages.kdenlive
	  shotcut
	  video-trimmer
	  xorg.xeyes
	  corefonts
	  vistafonts
	  vscode
	  linux-wifi-hotspot
    ];
  };

  nix = {
    settings = {
      auto-optimise-store = true;
      # https://discourse.nixos.org/t/nixos-rebuild-using-nix-var-nix-builds-instead-of-tmp-for-intermediate-build-outputs/70607
      # Defaults to /nix/var/nix/builds (not a tmpfs) by default. No longer need to specify to build on disk with a /tmp on tmpfs
      # build-dir = "/var/tmp";
  	};
  	gc = {
  	  automatic = !(config.programs.nh.enable && config.programs.nh.clean.enable);
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
  	noto-fonts-monochrome-emoji
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  qt = {
  	enable = true;
  	# platformTheme = "qt5ct";
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
    nh = {
      enable = true;
      flake = "/etc/nixos";
      clean = {
        enable = true;
        extraArgs = "--keep-since 7d --keep 10";
      };
    };
    appimage = {
      enable = true;
      binfmt = true;
    };
	dconf.enable = true;
	#ssh.startAgent = true;

	# Enabling Seahorse globally has issues with Plasma -- Manually using for Sway instead
	#seahorse.enable = true;
	#ssh = {
	#  enableAskPassword = true;
	#  askPassword = pkgs.lib.mkForce "${pkgs.seahorse.out}/libexec/seahorse/ssh-askpass";
	#};
  
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

    hyprland = {	
      enable = true; # I don't condone Vaxry, but I need tiling + HDR
      #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    };
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
  	  useEmbeddedBitmaps = true; # Fixes Firefox emoji
  	};
  };

  services = {
    power-profiles-daemon.enable = true;
    fwupd.enable = true;

    displayManager.sddm = {
  	  enable = true;
  	  theme = "catppuccin-mocha-maroon";
  	  extraPackages = lib.mkForce [ ];
  	  settings = {
  	  	Theme.CursorTheme = "XCursor-Pro-Dark";
  	  };

  	  # https://github.com/NixOS/nixpkgs/issues/292761
  	  # package = pkgs.lib.mkForce pkgs.libsForQt5.sddm;
  	  package = lib.mkForce pkgs.kdePackages.sddm;

  	  wayland = {
  	    enable = true;
  	    compositorCommand =
  	      let
  	        settingsFormat = pkgs.formats.keyValue { };
  	        sunshineCfg = settingsFormat.generate "sunshine.conf" config.services.sunshine.settings;
  	        highestRefresh = pkgs.writeShellScript "sway-highest-refresh" ''
  	          #!/usr/bin/env bash
  	          # Get JSON of outputs with best mode
  	          outputs_json=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq '
  	            [ .[]
  	              | .current_mode.width as $cw
  	              | .current_mode.height as $ch
  	              | {
  	                  name,
  	                  current_mode,
  	                  best_mode:
  	                    (.modes
  	                     | map(select(.width == $cw and .height == $ch))
  	                     | max_by(.refresh))
  	                }
  	            ]
  	          ')
  	          
  	          # Iterate over each output and set the mode
  	          echo "$outputs_json" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r output; do
  	            name=$(${pkgs.jq}/bin/jq -r '.name' <<<"$output")
  	            width=$(${pkgs.jq}/bin/jq -r '.best_mode.width' <<<"$output")
  	            height=$(${pkgs.jq}/bin/jq -r '.best_mode.height' <<<"$output")
  	            refresh_milli=$(${pkgs.jq}/bin/jq -r '.best_mode.refresh' <<<"$output")
  	          
  	            # Convert millihertz to hertz with 3 decimal places
  	            refresh=$(${pkgs.gawk}/bin/awk "BEGIN {printf \"%.3f\", $refresh_milli/1000}")

  	            if [ "$width" != "null" ]; then
  	              echo "Setting output '$name' to mode ''${width}x''${height}@''${refresh}Hz"
  	              ${pkgs.sway}/bin/swaymsg output "$name" mode "''${width}x''${height}@''${refresh}Hz"
  	            fi
  	          done
  	        '';
  	        monitorScale = pkgs.writeShellScript "monitor-scale" ''
  	          #!/usr/bin/env bash

  	          if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  	            echo "Usage: $0 <output_name> [target_dpi]" >&2
  	            exit 1
  	          fi

  	          output="$1"

  	          # $2 = optional user target DPI
  	          if [ -n "''${2:-}" ]; then
  	            target_dpi="$2"
  	            # "''$()
  	          else
  	            if [[ "$output" == eDP-* ]]; then
  	              target_dpi=155  # Laptop target DPI
  	            else
  	              target_dpi=110  # Desktop monitor target DPI (Matches 27" 1440p)
  	            fi
  	          fi

  	          # --- Find DRM connector ---
  	          edid_path=""
  	          for dir in /sys/class/drm/*; do
  	            if [ -d "$dir" ] && [[ "$(${pkgs.coreutils}/bin/basename "$dir")" == *-"$output" ]]; then
  	              edid_path="$dir"
  	              break
  	            fi
  	          done

  	          if [ -z "$edid_path" ]; then
  	            echo "Error: no DRM connector found for $output" >&2
  	            exit 1
  	          fi

  	          edid_file="$edid_path/edid"
  	          if [ ! -f "$edid_file" ]; then
  	            echo "Error: no EDID data found for $output" >&2
  	            exit 1
  	          fi

  	          # --- Extract physical size from EDID (in cm) ---
  	          read mw mh <<<$(${pkgs.edid-decode}/bin/edid-decode "$edid_file" 2>/dev/null | ${pkgs.gawk}/bin/awk '/Maximum image size:/ {print $4, $7; exit}')
  	          if [ -z "''${mw:-}" ] || [ -z "''${mh:-}" ]; then
  	            echo "Error: could not parse physical size from EDID for $output" >&2
  	            exit 1
  	          fi

  	          # --- Get current resolution from Sway ---
  	          width=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r | ${pkgs.jq}/bin/jq -r --arg name "$output" '.[] | select(.name==$name) | .current_mode.width')
  	          height=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r | ${pkgs.jq}/bin/jq -r --arg name "$output" '.[] | select(.name==$name) | .current_mode.height')

  	          if [ -z "''${width:-}" ] || [ -z "''${height:-}" ]; then
  	            echo "Error: could not query resolution for $output" >&2
  	            exit 1
  	          fi

  	          # --- Compute DPI ---
  	          dpi=$(${pkgs.gawk}/bin/awk -v w=$width -v h=$height -v mw=$mw -v mh=$mh \
  	            'BEGIN { print sqrt((w*w + h*h)) / sqrt((mw/2.54)^2 + (mh/2.54)^2) }')

  	          # --- Compute recommended Sway scale ---
  	          scale=$(${pkgs.gawk}/bin/awk -v dpi=$dpi -v target=$target_dpi 'BEGIN { printf "%.2f", dpi/target }')
  	          # --- Round scale *up* to the next 0.05 step to avoid blurry fractional scaling ---
  	          rounded_scale=$(${pkgs.gawk}/bin/awk -v s="$scale" 'BEGIN { printf "%.2f", (int((s*20)+0.9999))/20 }')

  	          echo "$rounded_scale"
  	        '';
  	        monitorQuery = pkgs.writeShellScript "monitor-query" ''
              #!/usr/bin/env bash

              ${pkgs.sway}/bin/swaymsg create_output "HEADLESS-1"
              ${pkgs.sway}/bin/swaymsg output "HEADLESS-1" pos 0 0

              # Define your list of preferred device names (or partial names) in order of priority
              PREFERRED_DEVICES=("Beihai Century Joint Innovation Technology Co.,Ltd" "AOC Q27G40XMN" "Acer Technologies VG271U" "Samsung Electric Company LC27T55") # Replace with actual display names or partial names

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
              
              # If no preferred device is connected, pick the first connected display by priority:
              # DP* > HDMI* > eDP* > others
              if [[ -z "$PRIMARY_DISPLAY" && -n "$CONNECTED_DISPLAYS" ]]; then
                PRIMARY_DISPLAY=$(echo "$CONNECTED_DISPLAYS" \
                  | ${pkgs.gawk}/bin/awk '
                    # Assign priorities
                    /^DP/   { pri=1 }
                    /^HDMI/ { pri=2 }
                    /^eDP/  { pri=3 }
                    !/^DP/ && !/^HDMI/ && !/^eDP/ { pri=4 }
                    { print pri, $0 }
                  ' \
                  | ${pkgs.coreutils}/bin/sort -k1,1n \
                  | ${pkgs.gawk}/bin/awk "{print \$2; exit}")
                echo "No preferred monitor found; defaulting to prioritized display: $PRIMARY_DISPLAY"
              fi

              # Export the primary display as an environment variable if a display was found
              if [[ -n "$PRIMARY_DISPLAY" ]]; then
                export PRIMARY_DISPLAY
                echo "SWAYSOCK: $SWAYSOCK"
                echo "Primary display set to: $PRIMARY_DISPLAY"

                # Disable all non-primary outputs
                ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"$PRIMARY_DISPLAY\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable

                # Enable, the primary display if it's disabled, scale
                scale="$(${monitorScale} $PRIMARY_DISPLAY)" || scale="1"
                ${pkgs.sway}/bin/swaymsg output "$PRIMARY_DISPLAY" pos 0 0 scale $scale
              else
                echo "No connected displays found."
              fi
  	        '';
            swayCfg = pkgs.writeText "sway.conf" ''
              output "*" {
                bg #000000 solid_color
              }
              input "type:touchpad" {
                tap enabled
                natural_scroll enabled
              }
              exec ${pkgs.bash}/bin/bash -c 'echo "$( ${monitorQuery} )" > /tmp/swaylog.txt'
              exec ${highestRefresh}
              #exec ${pkgs.bash}/bin/bash -c "sleep 5 && ${pkgs.wayvnc}/bin/wayvnc 127.0.0.1 --log-level=info > /tmp/wayvnc_login; ${pkgs.procps}/bin/kill `${pkgs.procps}/bin/pgrep sunshine`; sleep 10 && rm -f /tmp/wayvnc_login"
              #exec ${pkgs.bash}/bin/bash -c "${pkgs.procps}/bin/kill `${pkgs.procps}/bin/pgrep sunshine`"
              exec ${pkgs.bash}/bin/bash -c "sleep 5 && ${pkgs.sunshine}/bin/sunshine ${sunshineCfg} > /tmp/sunshine_login"
            '';
          in
          #"/usr/bin/env WLR_BACKENDS=drm,headless,libinput WLR_RENDERER=vulkan ${pkgs.sway}/bin/sway -c ${swayCfg} --unsupported-gpu";
          # Vulkan backend breaks with sunshine: https://github.com/swaywm/sway/issues/8765#issuecomment-2975196895
          "/usr/bin/env WLR_BACKENDS=drm,headless,libinput WLR_RENDERER=gles2 ${pkgs.sway}/bin/sway -c ${swayCfg} --unsupported-gpu";
  	  };
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
 	  #packages = [
 	    #(lib.optionals config.services.sunshine.enable (pkgs.writeTextFile {
 	    #  name = "60-sunshine-extra.rules";
 	    #  text = ''KERNEL=="uhid", TAG+="uaccess"'';
 	    #  destination = "/etc/udev/rules.d/60-sunshine-extra.rules";
 	    #}))
 	  #];
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
  
  systemd = {
    # Hail Mary to prevent remote shutdown hangs
    settings.Manager = {
      DefaultTimeoutStopSec = "1min";
      DefaultTimeoutStartSec = "1min";
      DefaultTimeoutAbortSec = "30s";
      RuntimeWatchdogSec = "30s";
    };

    # Create a separate slice for nix-daemon that is
    # memory-managed by the userspace systemd-oomd killer
    slices."nix-daemon" = {
      sliceConfig = {
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "50%";
      };
    };

    services = {
      "nix-daemon".serviceConfig = {
        Slice = "nix-daemon.slice";

        # If a kernel-level OOM event does occur anyway,
        # strongly prefer killing nix-daemon child processes
        # OOM configuration: https://discourse.nixos.org/t/nix-build-ate-my-ram/35752
        OOMScoreAdjust = 1000;
      };
      power-profiles-daemon.wantedBy = [ "multi-user.target" ];

      "systemd-journald".serviceConfig = {
        TimeoutStartSec = "10s";
        TimeoutStopSec = "10s";
      };

      sddm-avatar = let get-sddm-avatars = pkgs.writeShellScript "get-sddm-avatars" ''
        for user in /home/*; do
          username=$(${pkgs.coreutils}/bin/basename $user)
          if [ -f "$user/.face.icon" ]; then
            cp -f "$user/.face.icon" "/var/lib/AccountsService/icons/$username"
          fi
        done
        ''; in {
        description = "Script to copy or update users Avatars at startup.";
        wantedBy = [ "multi-user.target" ];
        before = [ "display-manager.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${get-sddm-avatars}";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
      };

      "ddcci@" = {
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
  	  elegant-sddm
  	  (pkgs.catppuccin-sddm.override {
  	    flavor = "mocha";
        accent = "maroon"; # List: https://github.com/catppuccin/sddm/releases/tag/v1.1.2
        userIcon = true;
  	    font  = "Inter";
  	    fontSize = "11";
  	    #background = "${./wallpaper.png}";
  	    loginBackground = true;
  	  })
  	  inter
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
  	  seahorse
  	] ++ gst_plugins;

    # TODO: Remove after https://github.com/NixOS/nixpkgs/issues/409986#issuecomment-3217982330
  	etc."xdg/menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

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
