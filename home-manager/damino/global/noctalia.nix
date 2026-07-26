{ inputs, config, pkgs, ... }: {
  imports = [
    inputs.noctalia.homeModules.default
  ];
  home.packages = [ inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  programs.noctalia = {
	enable = true;

	settings = {
	  bar.default = {
	    background_opacity = 0.98;
	    end = [ "tray" "notifications" "wlr-hdr-cal" "network" "bluetooth" "volume" "battery" "session" "launcher" ];
	    font_weight = 700;
	    margin_edge = 0.0;
	    margin_ends = 0.0;
	    padding = 8;
	    radius = 0;
	    shadow = false;
	    start = [ "workspaces" ];
	    thickness = 24;
	    widget_spacing = 10;
	  };

	  control_center.shortcuts = [
	    { type = "wifi"; }
	    { type = "bluetooth"; }
	    { type = "caffeine"; }
	    { type = "notification"; }
	    { type = "power_profile"; }
	    { type = "audio"; }
	  ];

	  desktop_widgets.enabled = false;
	  dock.launcher_position = "start";
	  notification.scale = 1.0;

      # Disable constant "Now Playing" pop-ups
	  osd.kinds.media = false;

	  shell = {
	    avatar_path = "/home/${config.home.username}/.face.icon";
	    clipboard_enabled = false;
	    font_family = "Inter Medium";
	    telemetry_enabled = false;
	    time_format = "{:%I:%M %p}";

	    panel.clipboard_placement = "attached";
	  };

	  theme = {
	    builtin = "Gruvbox";
	    community_palette = "Cream Autumn Old";
	    custom_palette = "base16";
	    source = "custom";
	    wallpaper_scheme = "m3-tonal-spot";

	    templates.enable_builtin_templates = false;
	  };

	  wallpaper = {
	    directory = "/home/${config.home.username}/Pictures/Wallpapers";

	    default.path = "/home/${config.home.username}/Pictures/Wallpapers/New Gridania.jpeg";
	    last.path = "/home/${config.home.username}/Pictures/Wallpapers/New Gridania.jpeg";
	  };

	  location = {
	    auto_locate = true;
	  };

	  weather = {
	    unit = "imperial";
	  };

	  widget = {
	    battery = {
	      display_mode = "graphic";
	      hide_when_full = true;
	      show_label = false;
	    };

	    bluetooth.hide_when_no_connected_device = true;
	    clock.format = "{:%I:%M %p}";
	    launcher.glyph = "circle-arrow-down-filled";
	    network.show_label = false;
	    tray.drawer = true;

	    "wlr-hdr-cal" = let
	      nightlight = pkgs.writeShellScript "nightlight" ''
	        #!/usr/bin/env bash

	        case "$1" in
	          toggle)
	            if ! ${pkgs.systemd}/bin/busctl --user get-property org.WlrHdrCal / org.WlrHdrCal Temperature 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^u 6500$'; then
	              ${pkgs.systemd}/bin/busctl --user set-property org.WlrHdrCal / org.WlrHdrCal Temperature u 6500
	            else
	              ${pkgs.systemd}/bin/busctl --user set-property org.WlrHdrCal / org.WlrHdrCal Temperature u 5000
	            fi
	            ;;
	          increase)
	            temp="$(${pkgs.systemd}/bin/busctl --user get-property org.WlrHdrCal / org.WlrHdrCal Temperature | ${pkgs.gawk}/bin/awk '{print $2}')"
	            if [ "$temp" -ge 6500 ]; then
	              ${pkgs.systemd}/bin/busctl --user set-property org.WlrHdrCal / org.WlrHdrCal Temperature u 6500
	            else
	              ${pkgs.systemd}/bin/busctl --user set-property org.WlrHdrCal / org.WlrHdrCal Temperature u "$((temp + 100))"
	            fi
	            ;;
	          decrease)
	            temp="$(${pkgs.systemd}/bin/busctl --user get-property org.WlrHdrCal / org.WlrHdrCal Temperature | ${pkgs.gawk}/bin/awk '{print $2}')"
	            ${pkgs.systemd}/bin/busctl --user set-property org.WlrHdrCal / org.WlrHdrCal Temperature u "$((temp - 100))"
	            ;;
	          status|*)
	            temp="$(${pkgs.systemd}/bin/busctl --user get-property org.WlrHdrCal / org.WlrHdrCal Temperature | ${pkgs.gawk}/bin/awk '{print $2}')"K
	            if ! echo $temp | ${pkgs.gnugrep}/bin/grep -q '^u 6500$'; then
	              echo "{\"text\":\"\",\"tooltip\":\"Color Temperature: $temp\"}"
	            else
	              echo "{\"text\":\"\",\"tooltip\":\"Color Temperature: $temp\"}"
	            fi
	            ;;
	        esac
	      ''; in {
	      enabled = true;
	      glyph = "nightlight-on";
	      type = "custom_button";
	      actions = {
	        left = "exec ${nightlight} toggle";
	        scroll_down = "exec ${nightlight} decrease";
	        scroll_up = "exec ${nightlight} increase";
	      };
	    };

	    workspaces = {
	      hide_when_empty = true;
	      focused_color = "outline";
	      occupied_color = "surface_variant";
	      empty_color = "surface_variant";
	    };
	  };
	};
  };

  home.file.".config/noctalia/palettes/base16.json".text = builtins.toJSON {
    dark = {
      mPrimary = "#${config.colorScheme.palette.base0B}";
      mOnPrimary = "#${config.colorScheme.palette.base00}";
      mSecondary = "#${config.colorScheme.palette.base0D}";
      mOnSecondary = "#${config.colorScheme.palette.base00}";
      mTertiary = "#${config.colorScheme.palette.base0A}";
      mOnTertiary = "#${config.colorScheme.palette.base00}";
      mError = "#${config.colorScheme.palette.base08}";
      mOnError = "#${config.colorScheme.palette.base00}";
      mSurface = "#${config.colorScheme.palette.base00}";
      mOnSurface = "#${config.colorScheme.palette.base07}";
      mSurfaceVariant = "#${config.colorScheme.palette.base01}";
      mOnSurfaceVariant = "#${config.colorScheme.palette.base04}";
      mOutline = "#${config.colorScheme.palette.base03}";
      mShadow = "#000000";
      mHover = "#${config.colorScheme.palette.base02}";
      mOnHover = "#${config.colorScheme.palette.base07}";
      terminal = {
        normal = {
          black = "#${config.colorScheme.palette.base00}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0E}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base05}";
        };
        bright = {
          black = "#${config.colorScheme.palette.base03}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0E}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base07}";
        };
        foreground = "#${config.colorScheme.palette.base05}";
        background = "#${config.colorScheme.palette.base00}";
        selectionFg = "#${config.colorScheme.palette.base00}";
        selectionBg = "#${config.colorScheme.palette.base02}";
        cursorText = "#${config.colorScheme.palette.base00}";
        cursor = "#${config.colorScheme.palette.base05}";
      };
    };
    light = {
      mPrimary = "#${config.colorScheme.palette.base0B}";
      mOnPrimary = "#${config.colorScheme.palette.base07}";
      mSecondary = "#${config.colorScheme.palette.base0D}";
      mOnSecondary = "#${config.colorScheme.palette.base07}";
      mTertiary = "#${config.colorScheme.palette.base0A}";
      mOnTertiary = "#${config.colorScheme.palette.base07}";
      mError = "#${config.colorScheme.palette.base08}";
      mOnError = "#${config.colorScheme.palette.base07}";
      mSurface = "#${config.colorScheme.palette.base07}";
      mOnSurface = "#${config.colorScheme.palette.base00}";
      mSurfaceVariant = "#${config.colorScheme.palette.base06}";
      mOnSurfaceVariant = "#${config.colorScheme.palette.base01}";
      mOutline = "#${config.colorScheme.palette.base04}";
      mShadow = "#000000";
      mHover = "#${config.colorScheme.palette.base05}";
      mOnHover = "#${config.colorScheme.palette.base00}";
      terminal = {
        normal = {
          black = "#${config.colorScheme.palette.base07}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0E}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base01}";
        };
        bright = {
          black = "#${config.colorScheme.palette.base04}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0E}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base00}";
        };
        foreground = "#${config.colorScheme.palette.base01}";
        background = "#${config.colorScheme.palette.base07}";
        selectionFg = "#${config.colorScheme.palette.base07}";
        selectionBg = "#${config.colorScheme.palette.base05}";
        cursorText = "#${config.colorScheme.palette.base07}";
        cursor = "#${config.colorScheme.palette.base01}";
      };
    };
  };
}
