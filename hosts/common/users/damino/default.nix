# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports =
    [
    	../../desktops/sway
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
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      home-manager
      #sway
      swayfx
      mesa-demos
      vulkan-tools
      #linuxKernel.packages.linux_zen.xpadneo
      #linuxKernel.packages.linux_zen.xone
      firefox
      kate
      kitty
      gnome.nautilus
      #steam
      steam-run
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
	  #fluent-gtk-theme
	  #fluent-icon-theme
	  #kora-icon-theme
    ];
  };

  nix = {
  	settings.auto-optimise-store = true;
  	gc = {
  	  automatic = true;
  	  dates = "daily";
  	  options = "--delete-older-than +5";
  	};
  };

  nixpkgs.config.input-fonts.acceptLicense = true;

  fonts.packages = with pkgs; [
  	fira-code
  	inter
  	input-fonts
  ];

  programs = {
	dconf.enable = true;
  
    zsh = {
	  enable = true;
	  enableCompletion = true;
	  #autosuggestions.enable = true;
	  shellAliases = {
	  	update = "sudo nix flake update /etc/nixos";
	  	upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#${config.networking.hostName}";
	  	update-home = "home-manager switch --flake /etc/nixos/.#damino@${config.networking.hostName}";
	  	#clear-boot = "sudo nix-collect-garbage --delete-generations 1 2 3";
	  };
	  ohMyZsh = {
	  	enable = true;
	  	plugins = [ "git" ];
	  	custom = "${config.users.users.damino.home}/.oh-my-zsh"; # TODO: Handle this with home-manager
	  	theme = "damino";
	  };
    };

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server	
    };
  };

  hardware = {
  	bluetooth.enable = true;
  	opengl.driSupport32Bit = true; # Enables support for 32bit libs that steam uses
  	xpadneo.enable = true;
  	xone.enable = true;
  	openrazer.enable = true;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  security = {
  	pam.enableEcryptfs = true;
  };

  boot = {
  	kernelModules = [ "ecryptfs" ];
  };

  environment.systemPackages = with pkgs; [
  	lsof
  	ecryptfs
  ];

  # If home-manager is managed by system:
  #home-manager.users.damino = import ../../../../home/damino/${config.networking.hostName}.nix;

}
