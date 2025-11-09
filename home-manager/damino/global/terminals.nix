{ inputs, config, pkgs, ... }: {
  programs.alacritty = {
    enable = true;
  
    settings = {
      window.opacity = 0.98;
  
      font = {
        normal.family = "Input Mono";
        normal.style = "Regular";
        size = 10.0;
        offset = { x = 0; y = -1; };
      };
  
      cursor = {
        style = { shape = "Block"; blinking = "Off"; };
        thickness = 0.6;
      };

      mouse.bindings = [
        { mouse = "Right"; mods = "None"; action = "None"; }
      ];
  
      scrolling.multiplier = 7;
  
      colors = {
        draw_bold_text_with_bright_colors = true;
        primary = {
          background = "#3B3228";
          foreground = "#d0c8c6";
        };
  
        cursor = {
          text = "#3B3228";
          cursor = "#d0c8c6";
        };
  
        selection = {
          text = "#3B3228";
          background = "#d0c8c6";
        };
  
        normal = {
          black = "#3B3228";
          red = "#cb6077";
          green = "#beb55b";
          yellow = "#f4bc87";
          blue = "#8ab3b5";
          magenta = "#a89bb9";
          cyan = "#7bbda4";
          white = "#d0c8c6";
        };
  
        bright = {
          black = "#7e705a";
          red = "#cb6077";
          green = "#beb55b";
          yellow = "#f4bc87";
          blue = "#8ab3b5";
          magenta = "#a89bb9";
          cyan = "#7bbda4";
          white = "#f5eeeb";
        };
  
        indexed_colors = [
          { index = 16; color = "#d28b71"; }
          { index = 17; color = "#bb9584"; }
          { index = 18; color = "#534636"; }
          { index = 19; color = "#645240"; }
          { index = 20; color = "#b8afad"; }
          { index = 21; color = "#e9e1dd"; }
        ];
      };
    };
  };
  
  programs.kitty = {
	enable = true;
	font = {
	  name = "Input Mono";
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
	  background_opacity = "0.98";
	  touch_scroll_multiplier = "7.0";

	  # Colors
	  background = "#${config.colorScheme.palette.base00}";
	  foreground = "#${config.colorScheme.palette.base05}";
	  selection_background = "#${config.colorScheme.palette.base05}";
	  selection_foreground = "#${config.colorScheme.palette.base00}";
	  url_color = "#${config.colorScheme.palette.base04}";
	  cursor = "#${config.colorScheme.palette.base05}";
	  active_border_color = "#${config.colorScheme.palette.base03}";
	  inactive_border_color = "#${config.colorScheme.palette.base01}";
	  active_tab_background = "#${config.colorScheme.palette.base00}";
	  active_tab_foreground = "#${config.colorScheme.palette.base05}";
	  inactive_tab_background = "#${config.colorScheme.palette.base01}";
	  inactive_tab_foreground = "#${config.colorScheme.palette.base04}";
	  tab_bar_background = "#${config.colorScheme.palette.base01}";

	  # Normal
	  color0 = "#${config.colorScheme.palette.base00}";
	  color1 = "#${config.colorScheme.palette.base08}";
	  color2 = "#${config.colorScheme.palette.base0B}";
	  color3 = "#${config.colorScheme.palette.base0A}";
	  color4 = "#${config.colorScheme.palette.base0D}";
	  color5 = "#${config.colorScheme.palette.base0E}";
	  color6 = "#${config.colorScheme.palette.base0C}";
	  color7 = "#${config.colorScheme.palette.base05}";

	  # Bright
	  color8 = "#${config.colorScheme.palette.base03}";
	  color9 = "#${config.colorScheme.palette.base08}";
	  color10 = "#${config.colorScheme.palette.base0B}";
	  color11 = "#${config.colorScheme.palette.base0A}";
	  color12 = "#${config.colorScheme.palette.base0D}";
	  color13 = "#${config.colorScheme.palette.base0E}";
	  color14 = "#${config.colorScheme.palette.base0C}";
	  color15 = "#${config.colorScheme.palette.base07}";

	  # Extended base16 colors
	  color16 = "#${config.colorScheme.palette.base09}";
	  color17 = "#${config.colorScheme.palette.base0F}";
	  color18 = "#${config.colorScheme.palette.base01}";
	  color19 = "#${config.colorScheme.palette.base02}";
	  color20 = "#${config.colorScheme.palette.base04}";
	  color21 = "#${config.colorScheme.palette.base06}";
	};
  };
}
