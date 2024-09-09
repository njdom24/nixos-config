{ inputs, config, pkgs, ... }: {
  programs.rofi = {
	enable = true;
	package = pkgs.rofi-wayland;

	extraConfig = {
	  show-icons = true;
	  sidebar-mode = true;
	};

	font = "${config.gtk.font.name} Bold 11.5";

	location = "left";

	theme = let inherit (config.lib.formats.rasi) mkLiteral; in {
	  "*" = {
		red = mkLiteral "rgba ( 203, 96, 119, 100 % )";
		blue = mkLiteral "rgba ( 138, 179, 181, 100 % )";
		lightfg = mkLiteral "rgba ( 233, 225, 221, 100 % )";
		lightbg = mkLiteral "rgba ( 83, 70, 54, 100 % )";
		foreground = mkLiteral "rgba ( 208, 200, 198, 100 % )";
		background = mkLiteral "rgba ( 59, 50, 40, 100 % )";
		background-color = mkLiteral "@background";

		separatorcolor = mkLiteral "@foreground";
		border-color = mkLiteral "@foreground";
		selected-normal-foreground = mkLiteral "@lightbg";
		selected-normal-background = mkLiteral "@lightfg";
		selected-active-foreground = mkLiteral "@background";
		selected-active-background = mkLiteral "@blue";
		selected-urgent-foreground = mkLiteral "@background";
		selected-urgent-background = mkLiteral "@red";
		normal-foreground = mkLiteral "@foreground";
		normal-background = mkLiteral "@background";
		active-foreground = mkLiteral "@blue";
		active-background = mkLiteral "@background";
		urgent-foreground = mkLiteral "@red";
		urgent-background = mkLiteral "@background";
		alternate-normal-foreground = mkLiteral "@foreground";
		alternate-normal-background = mkLiteral "@lightbg";
		alternate-active-foreground = mkLiteral "@blue";
		alternate-active-background = mkLiteral "@lightbg";
		alternate-urgent-foreground = mkLiteral "@red";
		alternate-urgent-background = mkLiteral "@lightbg";

		text-color = mkLiteral "@separatorcolor";
		accent-color = mkLiteral "@lightfg";
		accent2-color = mkLiteral "@lightfg";
		hover-color = mkLiteral "@lightfg";
		window-color = mkLiteral "@background-color";
	  };

	  "#window" = {
		anchor = mkLiteral "west";
		#location =  = mkLiteral "west";
		width = mkLiteral "12%";
		height = mkLiteral "100%";
	  };

	  "#mainbox" = {
		children = map mkLiteral [ "entry" "listview" "mode-switcher" ];
	  };

	  "entry" = {
		expand = false;
		margin = mkLiteral "8px";
	  };

	  "element" = {
		padding = mkLiteral "8px";
		margin = mkLiteral "-1px";
	  };

	  "element normal.normal" = {
		background-color = mkLiteral "@normal-background";
		text-color = mkLiteral "@normal-foreground";
	  };

	  "element normal.urgent" = {
		background-color = mkLiteral "@urgent-background";
		text-color = mkLiteral "@urgent-foreground";
	  };

	  "element normal.active" = {
		background-color = mkLiteral "@active-background";
		text-color = mkLiteral "@active-foreground";
	  };

	  "element selected.normal" = {
		background-color = mkLiteral "@selected-normal-background";
		text-color = mkLiteral "@selected-normal-foreground";
		border = mkLiteral "0 4px solid 0 0";
		border-color = mkLiteral "@accent2-color";
	  };

	  "element selected.urgent" = {
		background-color = mkLiteral "@selected-urgent-background";
		text-color = mkLiteral "@selected-urgent-foreground";
	  };

	  "element selected.active" = {
		background-color = mkLiteral "@selected-active-background";
		text-color = mkLiteral "@selected-active-foreground";
	  };

	  "element alternate.normal" = {
		background-color = mkLiteral "@normal-background";
		text-color = mkLiteral "@normal-foreground";
	  };

	  "element alternate.urgent" = {
		background-color = mkLiteral "@urgent-background";
		text-color = mkLiteral "@urgent-foreground";
	  };

	  "element alternate.active" = {
		background-color = mkLiteral "@active-background";
		text-color = mkLiteral "@active-foreground";
	  };

	  "element-icon" = {
		size = mkLiteral "2.2ch";
	  };

	  "element-text, element-icon" = {
		background-color = mkLiteral "inherit";
		text-color = mkLiteral "inherit";
	  };

	  "button" = {
		padding = mkLiteral "8px";
	  };

	  "button selected" = {
		background-color = mkLiteral "@active-background";
		text-color = mkLiteral "@background-color";
	  };
	};
  };
}
