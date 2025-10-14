{ inputs, config, pkgs, ... }: {
  programs = {
    zsh = {
	  enable = true;
	  enableCompletion = true;
	  shellAliases = {
	    update = "sudo nix flake update --flake /etc/nixos/";
	    #upgrade = "sudo nixos-rebuild switch --flake /etc/nixos/.#";
	    #hm-upgrade = "home-manager switch --flake /etc/nixos/.";
	  };
	  initContent = ''
	    upgrade() {
	      ${pkgs.nh}/bin/nh os switch /etc/nixos -- "$@"
	      #sudo nixos-rebuild switch --flake /etc/nixos/.# "$@"
	    }
	    hm-upgrade() {
	      # https://github.com/nix-community/home-manager/issues/6564
	      TMPDIR=/var/tmp/ ${pkgs.nh}/bin/nh home switch /etc/nixos -b old -- "$@"
	      #home-manager switch --flake /etc/nixos/. "$@" -b old
	    }
	    nix-find-insecure() {
          if [ -z "$1" ]; then
            echo "Usage: nix-find-insecure <package-name-ver>"
            return 1
          fi

          pkg="$1"
          nix-store -q --referrers /nix/store/*$pkg
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
  };
}
