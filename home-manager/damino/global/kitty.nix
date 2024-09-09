{ inputs, config, pkgs, ... }: {
  programs.kitty = {
	enable = true;
	font = {
	  name = "Input";
	  package = pkgs.input-fonts;
	  size = 10;
	};
	shellIntegration.mode = "enabled";

	settings = {
	  disable_ligatures = "always";
	  adjust_column_width = 0;
	  cursor_blink_interval = 0;
	  enable_audio_bell = false;
	  cursor_shape = "block";
	  cursor_beam_thickness = 6;
	  background_opacity = "0.96";
	  touch_scroll_multiplier = "7.0";

	  # Colors
	  background = "#3b3228";
	  foreground = "#d0c8c6";
	  selection_background = "#d0c8c6";
	  selection_foreground = "#3b3228";
	  url_color = "#b8afad";
	  cursor = "#d0c8c6";
	  active_border_color = "#7e705a";
	  inactive_border_color = "#534636";
	  active_tab_background = "#3b3228";
	  active_tab_foreground = "#d0c8c6";
	  inactive_tab_background = "#534636";
	  inactive_tab_foreground = "#b8afad";
	  tab_bar_background = "#534636";

	  # Normal
	  color0 = "#3b3228";
	  color1 = "#cb6077";
	  color2 = "#beb55b";
	  color3 = "#f4bc87";
	  color4 = "#8ab3b5";
	  color5 = "#a89bb9";
	  color6 = "#7bbda4";
	  color7 = "#d0c8c6";

	  # Bright
	  color8 = "#7e705a";
	  color9 = "#cb6077";
	  color10 = "#beb55b";
	  color11 = "#f4bc87";
	  color12 = "#8ab3b5";
	  color13 = "#a89bb9";
	  color14 = "#7bbda4";
	  color15 = "#f5eeeb";

	  # Extended base16 colors
	  color16 = "#d28b71";
	  color17 = "#bb9584";
	  color18 = "#534636";
	  color19 = "#645240";
	  color20 = "#b8afad";
	  color21 = "#e9e1dd";
	};
  };
}
