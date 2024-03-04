# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;

  gst_plugins = (with pkgs.gst_all_1; [
	gst-plugins-good
	gst-plugins-bad
	gst-plugins-ugly
	gst-libav
  ]);

in
{
  imports =
    [
    	../../desktops/sway
    	inputs.nur.nixosModules.nur
    	"${inputs.nixpkgs-unstable}/nixos/modules/hardware/corectrl.nix" # TODO: Remove after 23.11
    ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  ];

  disabledModules = [ "hardware/corectrl.nix" ]; # TODO: Remove after 23.11

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
      nvtop
      handbrake
      firefox
      chromium
      kate
      kitty
      gnome.nautilus
      gimp
      vlc
      steam-run
      steamtinkerlaunch
      moonlight-qt
      lutris
      vkbasalt
      protontricks
      protonup-qt
      neofetch
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
	  #discord
	  (discord.override {
	  	withOpenASAR = true;
	  })
	  #betterdiscord-installer
	  betterdiscordctl
	  unstable.discord-screenaudio
	  unstable.ryujinx
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
    ]# ++ (with dotnetCorePackages; [
    #	sdk_5_0
    #])
    ++ (with config.nur.repos; [
    	#mic92.hello-nur
    	wolfangaukang.vdhcoapp
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
  	platformTheme = "gtk2";
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
        extraEnv = {};
        extraLibraries = pkgs: with pkgs; [
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
        ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    corectrl = {
      enable = true;
      package = pkgs.unstable.corectrl;
      gpuOverclock.enable = true;	
    };

    gamemode.enable = true;

    virt-manager.enable = true;
  };

  virtualisation.libvirtd.enable = true;

  hardware = {
    bluetooth = {
    	enable = true;
    	powerOnBoot = true;
    	package = pkgs.legacy.bluez;
    };
  	opengl = {
  		driSupport32Bit = true; # Enables support for 32bit libs that steam uses
  		extraPackages = with pkgs; [mangohud intel-media-driver vaapiIntel vaapiVdpau libvdpau-va-gl ];
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
    xserver = {
   	  displayManager.sddm = {
  	    enable = true;
  	    theme = "chili";	
  	  };
  	  #displayManager.gdm = {
  	  #	 enable = true;
  	  #	 wayland = false;
  	  #};
  	  #displayManager.setupCommands = ''
  	  #  ${config.nur.repos.wolfangaukang.vdhcoapp}/net.downloadhelper.coapp install --user
  	  #  #etc/profiles/per-user/damino/share/vdhcoapp/net.downloadhelper.coapp install --user
  	  #'';
	  #videoDrivers = [ "modesetting" "fbdev" "nvidia" ];
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
  	  xdotool
  	  ecryptfs
  	  unzip
  	  ethtool
  	  gtk3
  	  pcmanfm
  	  #wineWowPackages.stagingFull
  	  wineWowPackages.waylandFull
  	  winetricks
  	  sddm-chili-theme
  	  xcursor-pro
  	  pciutils
  	  libgcc
  	  bison
  	  flex
  	  freetype
  	  OVMFFull
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
}
