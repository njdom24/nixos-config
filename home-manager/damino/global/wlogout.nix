{ inputs, config, pkgs, ... }: {
  programs.wlogout = {
	enable = true;

	layout = [
	  {
		label = "lock";
		action = "${pkgs.swaylock}/bin/swaylock -c ${config.lib.stylix.colors.base00}";
		text = "Lock";
		keybind = "l";
	  }
	  {
		label = "hibernate";
		action = "${pkgs.systemd}/bin/systemctl hibernate";
		text = "Hibernate";
		keybind = "h";
	  }
	  {
		label = "logout";
		action = pkgs.writeShellScript "wm-exit" ''
		  case "$XDG_CURRENT_DESKTOP" in
		    sway)
		      ${pkgs.sway}/bin/swaymsg exit
		      ;;
		    Hyprland)
		      ${pkgs.hyprland}/bin/hyprctl dispatch exit
		      ;;
		    *)
		      echo "Unknown desktop: $XDG_CURRENT_DESKTOP" >&2
		      ;;
		  esac
		'';
		text = "Logout";
		keybind = "e";
	  }
	  {
		label = "shutdown";
		action = "${pkgs.systemd}/bin/systemctl poweroff";
		text = "Shutdown";
		keybind = "s";
	  }
	  {
		label = "suspend";
		action = "${pkgs.systemd}/bin/systemctl suspend";
		text = "Suspend";
		keybind = "u";
	  }
	  {
		label = "reboot";
		action = "${pkgs.systemd}/bin/systemctl reboot";
		text = "Reboot";
		keybind = "r";
	  }
	];
	
	style =
''

@define-color base00 #${config.lib.stylix.colors.base00};
@define-color base01 #${config.lib.stylix.colors.base01};
@define-color base02 #${config.lib.stylix.colors.base02};
@define-color base03 #${config.lib.stylix.colors.base03};
@define-color base04 #${config.lib.stylix.colors.base04};
@define-color base05 #${config.lib.stylix.colors.base05};
@define-color base06 #${config.lib.stylix.colors.base06};
@define-color base07 #${config.lib.stylix.colors.base07};
@define-color base08 #${config.lib.stylix.colors.base08};
@define-color base09 #${config.lib.stylix.colors.base09};
@define-color base0A #${config.lib.stylix.colors.base0A};
@define-color base0B #${config.lib.stylix.colors.base0B};
@define-color base0C #${config.lib.stylix.colors.base0C};
@define-color base0D #${config.lib.stylix.colors.base0D};
@define-color base0E #${config.lib.stylix.colors.base0E};
@define-color base0F #${config.lib.stylix.colors.base0F};

* {
	background-image: none;
}

window {
	background-color: rgba(12, 12, 12, 0.8);
}

button {
    color: @base05;
	background-color: @base02;
	border-style: solid;
	border-width: 2px;
	background-repeat: no-repeat;
	background-position: center;
	background-size: 25%;
}

button:focus, button:active, button:hover {
    color: @base02;
	background-color: @base07;
	outline-style: none;
}

#lock {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
	background-blend-mode: luminosity;
}

#logout {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
	background-blend-mode: luminosity;
}

#suspend {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
	background-blend-mode: luminosity;
}

#hibernate {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
	background-blend-mode: luminosity;
}

#shutdown {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
	background-blend-mode: luminosity;
}

#reboot {
	background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
	background-blend-mode: luminosity;
}
'';
  };
}
