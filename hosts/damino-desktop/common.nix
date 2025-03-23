# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [
      ../common/users/damino
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  #services.xserver.displayManager.gdm.enable = true;
  # Enable the KDE Plasma Desktop Environment.
  #services.xserver.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  security.rtkit.enable = true;
  
  services = {
    udev = {
      extraHwdb = ''
        evdev:atkbd:dmi:bvn*:bvr*:bd*:br*:efr*:svnGPD:pnMicroPC:*
          KEYBOARD_KEY_36=sysrq  # Right Shift -> SysRq
      '';
    };
  	# Enable the X11 windowing system.
    xserver = {
  	  enable = true;
  	  # Configure keymap in X11
  	  xkb = {
  	    layout = "us";
  	    variant = "";
  	  };
  	  videoDrivers = [ "amdgpu" "modesetting" "fbdev" ];
  	  # Only show login screen on primary monitor when it's connected
  	  displayManager.setupCommands = ''  	  
  	    if [ "$(${pkgs.xorg.xrandr}/bin/xrandr --current | ${pkgs.gnugrep}/bin/grep 'DisplayPort-0 connected')" ]; then
  	      ${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-0 --auto --primary
  	      ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-A-0 --off
  	      ${pkgs.xorg.xrandr}/bin/xrandr --output DisplayPort-1 --off
  	    fi
  	  '';
    };

    pulseaudio.enable = false;  
  	pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    sunshine = {
      enable = true;
      autoStart = false;
      capSysAdmin = true;
      openFirewall = true;
      package = pkgs.unstable.sunshine.override {
      	libgbm = pkgs.mesa; # TODO: Change to pkgs.libgbm in 25.05
      };
      applications.apps = [
        {
          name = "Desktop";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = pkgs.writeShellScript "set-client-res" ''
                #!/usr/bin/env bash
                if [ -z "$SWAYSOCK" && -z "$WAYLAND_DISPLAY" ]; then
                  SWAYSOCK=/run/user/$(id -u)/sway-ipc.$(id -u).$(pgrep -x sway).sock
                fi
                
                if ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -e '.[] | select(.name == "HEADLESS-1")' > /dev/null; then
                  mode="$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
                  ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode $mode
                else
                  echo "Not headless"
                fi
              '';
            }
          ];
        }
      ];
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  #users.users.damino = {
  #  isNormalUser = true;
  #  description = "damino";
  #  extraGroups = [ "networkmanager" "wheel" ];
  #  packages = with pkgs; [
  #    firefox
  #    kate
    #  thunderbird
  #  ];
  #};

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    git
    micro
    x11vnc
    wayvnc
    #sunshine

    # Monitor scripts
    (pkgs.writeShellScriptBin "enable-dimming" ''
      #!/usr/bin/env bash
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 6c 50 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 70 50 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 6e 50 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      
      #while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 12 69 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
    '')
    (pkgs.writeShellScriptBin "disable-dimming" ''
      #!/usr/bin/env bash
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 6c 51 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 70 51 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 6e 51 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
      
      #while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 12 64 --model="Mi Monitor" --sleep-multiplier=0.025; do sleep 0.1; done
    '')
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # XIVLauncher App
  networking.firewall = {
  	allowedTCPPorts = [
  		4646
  	];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
