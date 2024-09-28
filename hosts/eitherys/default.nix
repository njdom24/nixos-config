# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
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
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./media.nix
      ./routing.nix
      ./storage.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.useTmpfs = true;

  networking.hostName = "eitherys"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking = {
  	dhcpcd.enable = true;
  	wireless.iwd.enable = false;
  	interfaces.enp1s0.wakeOnLan.enable = true;
  };

  # Set your time zone.
  time = {
  	timeZone = "America/New_York";
  	# hardwareClockInLocalTime = true;
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services = {
    resolved.enable = true;

    openssh = {
      enable = true;
      settings = {
      	X11Forwarding = true;
      	PasswordAuthentication = true;
      };
    };

    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;

    fstrim.enable = true;

    apcupsd = {
      enable = true;
      configText = ''
        UPSTYPE usb
        NISIP 127.0.0.1
        ONBATTERYDELAY 6
        BATTERYLEVEL 10
        MINUTES 3
        TIMEOUT 0
        ANNOY 300
        ANNOYDELAY 60
        BEEPSTATE T
      '';
    };
  };

  hardware = {
  	#opengl.extraPackages = with pkgs; [ vpl-gpu-rt ]; #  24.10+
  	opengl.extraPackages = with pkgs; [ onevpl-intel-gpu ];
  	intel-gpu-tools.enable = true;
  };

  security.rtkit.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.elpis = {
    isNormalUser = true;
    description = "elpis";
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
    	"jellyfin"
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
      kitty
      ffmpeg-full
      libva-utils
      steam-run
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
	  blueberry
	  cinnamon.warpinator
	  gnome.gnome-disk-utility
	  gnome.gnome-system-monitor
	  libnotify
	  xwaylandvideobridge
	  xorg.xeyes
	  corefonts
	  vistafonts
	  zip
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
  	};
  	gc = {
  	  automatic = true;
  	  dates = "weekly";
  	  options = "--delete-older-than 7d";
  	};
  };

  nixpkgs.config.input-fonts.acceptLicense = true;

  programs = {
	dconf.enable = true;
	seahorse.enable = true;
	ssh = {
	  enableAskPassword = true;
	  askPassword = pkgs.lib.mkForce "${pkgs.gnome.seahorse.out}/libexec/seahorse/ssh-askpass";
	};

    zsh.enable = true;
    virt-manager.enable = true;

    msmtp = {
      enable = true;
      accounts = {
      	default = {
      	  auth = true;
      	  tls = true;
      	  tls_starttls = false;
      	  from = "dom32400@gmail.com";
      	  host = "smtp.gmail.com";
      	  user = "dom32400";
      	  passwordeval = "cat /var/secrets/msmtp";
      	};
      };
    };
  };

  virtualisation = {
  	libvirtd.enable = true;
  	docker.enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    micro
    x11vnc
    wayvnc
    lsof
    file
    sshfs
    libarchive
    p7zip
    unzip
    duperemove
    xdotool
    ecryptfs
    ethtool
    wineWowPackages.waylandFull
    winetricks
    pciutils
    libgcc
    bison
    flex
    OVMFFull
    python3
    distrobox
    waypipe
  ] ++ gst_plugins;

  #variables = {
  #	"GST_PLUGIN_SYSTEM_PATH_1_0" = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gst_plugins;
  #};

  #extraInit = "source ${config.users.users.elpis.home}/.nix-profile/etc/profile.d/hm-session-vars.sh";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  networking.firewall = {
  	allowedTCPPorts = [
  	  80
  	  443
  	];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}
