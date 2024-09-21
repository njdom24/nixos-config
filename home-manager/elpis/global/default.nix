
# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  hostName,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      input-fonts.acceptLicense = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    username = "elpis";
    homeDirectory = "/home/elpis";
    sessionPath = [ "$HOME/.local/bin" ];
    # sessionVariables = { };

    packages = with pkgs; [
    ];
  };

  # Enable home-manager and git
  programs = {
    home-manager.enable = true;
  	git = {
  	  enable = true;
  	  package = pkgs.gitFull;
  	  extraConfig = {
  	    safe.directory = "/etc/nixos/.git";
  	  	credential.helper = "libsecret";
  	  };
  	  userName = "Damino";
  	  userEmail = "dom32400@aol.com";
  	};

	zsh = {
	  enable = true;
	  enableCompletion = true;
	  shellAliases = {
	  	update = "sudo nix flake update /etc/nixos";
	  	upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#";
	  	update-home = "home-manager switch --flake /etc/nixos/.";
	  };
	  oh-my-zsh = {
	  	enable = true;
	  	plugins = [ "git" ];
	  	custom = ".oh-my-zsh";
	  	theme = "damino";
	  };
	  localVariables = {
	  	TERM = "xterm-256color"; # Fixes kitty ssh
	  };
	};
  };

  services = {
  	syncthing.enable = true;
  };

  systemd.user = {
    # Nicely reload system units when changing configs
    startServices = "sd-switch";
    services = {
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11";
}
