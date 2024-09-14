{ inputs, config, pkgs, ... }: {
  programs.wlogout = {
	enable = true;

	layout = [
	  {
		label = "lock";
		action = "${pkgs.swaylock}/bin/swaylock -c ${config.colorScheme.palette.base00}";
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
		action = "${pkgs.sway}/bin/swaymsg exit";
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

@define-color base00 #${config.colorScheme.palette.base00};
@define-color base01 #${config.colorScheme.palette.base01};
@define-color base02 #${config.colorScheme.palette.base02};
@define-color base03 #${config.colorScheme.palette.base03};
@define-color base04 #${config.colorScheme.palette.base04};
@define-color base05 #${config.colorScheme.palette.base05};
@define-color base06 #${config.colorScheme.palette.base06};
@define-color base07 #${config.colorScheme.palette.base07};
@define-color base08 #${config.colorScheme.palette.base08};
@define-color base09 #${config.colorScheme.palette.base09};
@define-color base0A #${config.colorScheme.palette.base0A};
@define-color base0B #${config.colorScheme.palette.base0B};
@define-color base0C #${config.colorScheme.palette.base0C};
@define-color base0D #${config.colorScheme.palette.base0D};
@define-color base0E #${config.colorScheme.palette.base0E};
@define-color base0F #${config.colorScheme.palette.base0F};

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
