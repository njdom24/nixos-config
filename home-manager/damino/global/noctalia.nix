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
      mPrimary = "#${config.lib.stylix.colors.base0B}";
      mOnPrimary = "#${config.lib.stylix.colors.base00}";
      mSecondary = "#${config.lib.stylix.colors.base0D}";
      mOnSecondary = "#${config.lib.stylix.colors.base00}";
      mTertiary = "#${config.lib.stylix.colors.base0A}";
      mOnTertiary = "#${config.lib.stylix.colors.base00}";
      mError = "#${config.lib.stylix.colors.base08}";
      mOnError = "#${config.lib.stylix.colors.base00}";
      mSurface = "#${config.lib.stylix.colors.base00}";
      mOnSurface = "#${config.lib.stylix.colors.base07}";
      mSurfaceVariant = "#${config.lib.stylix.colors.base01}";
      mOnSurfaceVariant = "#${config.lib.stylix.colors.base04}";
      mOutline = "#${config.lib.stylix.colors.base03}";
      mShadow = "#000000";
      mHover = "#${config.lib.stylix.colors.base02}";
      mOnHover = "#${config.lib.stylix.colors.base07}";
      terminal = {
        normal = {
          black = "#${config.lib.stylix.colors.base00}";
          red = "#${config.lib.stylix.colors.base08}";
          green = "#${config.lib.stylix.colors.base0B}";
          yellow = "#${config.lib.stylix.colors.base0A}";
          blue = "#${config.lib.stylix.colors.base0D}";
          magenta = "#${config.lib.stylix.colors.base0E}";
          cyan = "#${config.lib.stylix.colors.base0C}";
          white = "#${config.lib.stylix.colors.base05}";
        };
        bright = {
          black = "#${config.lib.stylix.colors.base03}";
          red = "#${config.lib.stylix.colors.base08}";
          green = "#${config.lib.stylix.colors.base0B}";
          yellow = "#${config.lib.stylix.colors.base0A}";
          blue = "#${config.lib.stylix.colors.base0D}";
          magenta = "#${config.lib.stylix.colors.base0E}";
          cyan = "#${config.lib.stylix.colors.base0C}";
          white = "#${config.lib.stylix.colors.base07}";
        };
        foreground = "#${config.lib.stylix.colors.base05}";
        background = "#${config.lib.stylix.colors.base00}";
        selectionFg = "#${config.lib.stylix.colors.base00}";
        selectionBg = "#${config.lib.stylix.colors.base02}";
        cursorText = "#${config.lib.stylix.colors.base00}";
        cursor = "#${config.lib.stylix.colors.base05}";
      };
    };
    light = {
      mPrimary = "#${config.lib.stylix.colors.base0B}";
      mOnPrimary = "#${config.lib.stylix.colors.base07}";
      mSecondary = "#${config.lib.stylix.colors.base0D}";
      mOnSecondary = "#${config.lib.stylix.colors.base07}";
      mTertiary = "#${config.lib.stylix.colors.base0A}";
      mOnTertiary = "#${config.lib.stylix.colors.base07}";
      mError = "#${config.lib.stylix.colors.base08}";
      mOnError = "#${config.lib.stylix.colors.base07}";
      mSurface = "#${config.lib.stylix.colors.base07}";
      mOnSurface = "#${config.lib.stylix.colors.base00}";
      mSurfaceVariant = "#${config.lib.stylix.colors.base06}";
      mOnSurfaceVariant = "#${config.lib.stylix.colors.base01}";
      mOutline = "#${config.lib.stylix.colors.base04}";
      mShadow = "#000000";
      mHover = "#${config.lib.stylix.colors.base05}";
      mOnHover = "#${config.lib.stylix.colors.base00}";
      terminal = {
        normal = {
          black = "#${config.lib.stylix.colors.base07}";
          red = "#${config.lib.stylix.colors.base08}";
          green = "#${config.lib.stylix.colors.base0B}";
          yellow = "#${config.lib.stylix.colors.base0A}";
          blue = "#${config.lib.stylix.colors.base0D}";
          magenta = "#${config.lib.stylix.colors.base0E}";
          cyan = "#${config.lib.stylix.colors.base0C}";
          white = "#${config.lib.stylix.colors.base01}";
        };
        bright = {
          black = "#${config.lib.stylix.colors.base04}";
          red = "#${config.lib.stylix.colors.base08}";
          green = "#${config.lib.stylix.colors.base0B}";
          yellow = "#${config.lib.stylix.colors.base0A}";
          blue = "#${config.lib.stylix.colors.base0D}";
          magenta = "#${config.lib.stylix.colors.base0E}";
          cyan = "#${config.lib.stylix.colors.base0C}";
          white = "#${config.lib.stylix.colors.base00}";
        };
        foreground = "#${config.lib.stylix.colors.base01}";
        background = "#${config.lib.stylix.colors.base07}";
        selectionFg = "#${config.lib.stylix.colors.base07}";
        selectionBg = "#${config.lib.stylix.colors.base05}";
        cursorText = "#${config.lib.stylix.colors.base07}";
        cursor = "#${config.lib.stylix.colors.base01}";
      };
    };
  };
}
