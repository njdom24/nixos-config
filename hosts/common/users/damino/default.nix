
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
    	inputs.nur.nixosModules.nur
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
      mesa-demos
      vulkan-tools
      nvtopPackages.full
      rclone
      handbrake
      firefox
      (chromium.override { enableWideVine = true; })
      kate
      kitty
      gnome.nautilus
      gnome.file-roller
      gimp
      vlc
      steam-run
      steamtinkerlaunch
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
	  cinnamon.warpinator
	  gnome.gnome-font-viewer
	  gnome.gnome-disk-utility
	  gnome.gnome-system-monitor
	  libnotify
	  xwaylandvideobridge
	  #discord
	  (discord.override {
	  	withOpenASAR = true; # If this breaks, set to false and re-run Discord. https://github.com/NixOS/nixpkgs/issues/208749
	  })
	  
	  #betterdiscord-installer
	  betterdiscordctl
	  unstable.vesktop
	  unstable.ludusavi
	  unstable.ryujinx
	  citra-mk7
	  dolphin-emu
	  unstable.cemu
	  (unstable.melonDS.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
	  (unstable.retroarch.override {
	    cores = with unstable.libretro; [
	      mgba
	    ];
  	  })
	  #obs-studio
	  (wrapOBS {
	  	plugins = with obs-studio-plugins; [
	  		wlrobs
	  		obs-pipewire-audio-capture
	  	];
	  })
	  jellyfin-media-player
	  xorg.xeyes
	  corefonts
	  vistafonts
	  vscode
    ]# ++ (with dotnetCorePackages; [
    #	sdk_5_0
    #])
    ++ (with config.nur.repos; [
    	#mic92.hello-nur
    	#wolfangaukang.vdhcoapp
    	#ivar.ryujinx
    ]);
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
  	noto-fonts-cjk
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
	  askPassword = pkgs.lib.mkForce "${pkgs.gnome.seahorse.out}/libexec/seahorse/ssh-askpass";
	};
  
    zsh = {
	  enable = true;
	#  enableCompletion = true;
	#  #autosuggestions.enable = true;
	#  shellAliases = {
	#  	update = "sudo nix flake update /etc/nixos";
	#  	upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#${config.networking.hostName}";
	#  	update-home = "home-manager switch --flake /etc/nixos/.#damino@${config.networking.hostName}";
	#  	#clear-boot = "sudo nix-collect-garbage --delete-generations 1 2 3";
	#  };
	#  ohMyZsh = {
	#  	enable = true;
	#  	plugins = [ "git" ];
	#  	custom = "${config.users.users.damino.home}/.oh-my-zsh"; # TODO: Handle this with home-manager
	#  	theme = "damino";
	#  };
    };

    adb.enable = true;

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server	
      package = pkgs.steam.override {
        # https://github.com/NixOS/nixpkgs/issues/279893
        extraProfile = ''
          unset TZ
        '';
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
        args = [
          "-f"	
        ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false; # Needed or gamescope fails within Steam
    };

    corectrl = {
      enable = true;
      package = pkgs.unstable.corectrl;
      gpuOverclock.enable = true;	
    };

    gamemode.enable = true;

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
  	opengl = {
  		driSupport32Bit = true; # Enables support for 32bit libs that steam uses
  		extraPackages = with pkgs; [mangohud intel-media-driver vaapiIntel vaapiVdpau libvdpau-va-gl vulkan-loader vulkan-validation-layers vulkan-extension-layer];
  		extraPackages32 = with pkgs; [mangohud];
  	};
  	#nvidia = {
  	  # Modesetting is required.
      #modesetting.enable = true;
  	#};
  	xpadneo.enable = true;
  	xone.enable = true;
  	openrazer.enable = true;
  };

  services = {
    displayManager.sddm = {
  	  enable = true;
  	  theme = "Elegant";
  	  settings = {
  	  	Theme.CursorTheme = "XCursor-Pro-Dark";
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
  	  settings.PasswordAuthentication = true;
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
  };

  environment = {
  	systemPackages = with pkgs; [
  	  lsof
  	  file
  	  wget
  	  sshfs
  	  libarchive
  	  p7zip
  	  duperemove
  	  xdotool
  	  ecryptfs
  	  unzip
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
