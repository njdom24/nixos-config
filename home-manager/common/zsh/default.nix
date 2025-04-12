{ inputs, config, pkgs, ... }: {
  programs.zsh = {
	enable = true;
	enableCompletion = true;
	shellAliases = {
	  update = "sudo nix flake update --flake /etc/nixos/";
	  upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#";
	  hm-upgrade = "home-manager switch --flake /etc/nixos/.";
	};
	oh-my-zsh = {
	 enable = true;
	 plugins = [ "git" ];
	 extraConfig = ''
	   source ${./damino.zsh-theme}
	 '';
	};
	localVariables = {
	  TERM = "xterm-256color"; # Fixes kitty ssh
	};
  };
}
