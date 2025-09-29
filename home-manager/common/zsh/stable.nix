{ inputs, config, pkgs, ... }: {
  programs.zsh = {
	enable = true;
	enableCompletion = true;
	shellAliases = {
	  update = "sudo nix flake update --flake /etc/nixos/";
	  #upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#";
	  #hm-upgrade = "home-manager switch --flake /etc/nixos/.";
	};
	initContent = ''
	  upgrade() {
	    TMP_BUILD_DIR="/var/tmp/nix-build"
	    mkdir -p "$TMP_BUILD_DIR"
	    chmod 1777 "$TMP_BUILD_DIR"
	    TMPDIR="$TMP_BUILD_DIR" ${pkgs.nh}/bin/nh os switch /etc/nixos -- --impure "$@"
	    #sudo nixos-rebuild switch --impure --flake /etc/nixos/.# "$@"
	    rm -rf "$TMP_BUILD_DIR"
	  }
	  hm-upgrade() {
	    TMP_BUILD_DIR="/var/tmp/nix-build"
	    mkdir -p "$TMP_BUILD_DIR"
	    chmod 1777 "$TMP_BUILD_DIR"
	    ${pkgs.nh}/bin/nh home switch /etc/nixos -- "$@"
	    #home-manager switch --flake /etc/nixos/. "$@"
	    rm -rf "$TMP_BUILD_DIR"
	  }
	'';
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
