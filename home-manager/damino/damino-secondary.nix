{ inputs, pkgs, lib, ... }: {
  imports = [ ./global ];

  wayland.windowManager = {
    sway.extraSessionCommands = ''
      export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0
    '';

    hyprland = {
        extraConfig = ''
          hl.env("AQ_DRM_DEVICES", xdgRuntimeDir .. "/dri/dgpu0")
          hl.monitor({
          	output   = "",
          	mode     = "preferred",
          	position = "auto",
          	scale    = 1,
          	mirror   = "DP-1",
          })
        '';
    };
  };

  programs = {
    rofi.yoffset = 24;

    noctalia.settings = {
      notifications = lib.mkDefault {
        monitors = [ "DP-2" ];
        position = "top_right";
      };
    };
  };

  services = {
    mako.settings = {
      output = "DP-2";
      anchor = lib.mkForce "top-left";
    };
    swaync.settings = {
      notification-window-preferred-output = lib.mkForce "DP-2";
      positionX = lib.mkForce "right";
    };

    kanshi.settings = [
      {
  	    profile = {
  	      name = "desktop";
  	      outputs = [
            {
              criteria = "AOC Q27G40XMN*";
              status = "enable";
              mode = "2560x1440@180Hz";
              position = "2560,0";
              #adaptiveSync = true;
            }
            {
              criteria = "Acer*VG271U";
              status = "enable";
              mode = "2560x1440@143.999Hz";
              position = "0,0";
              #position = "2560,0";
              #adaptiveSync = true;
            }
            {
              criteria = "*55R635*";
              status = "disable";
              mode = "2560x1440@120Hz";
              position = "5120,0";
              #adaptiveSync = true;
            }
          ];
          exec = [
            "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
            "${pkgs.sway}/bin/swaymsg output DP-1 hdr on"
          ];
        };
      }
      {
        profile = {
          name = "desktop-headless";
          outputs = [
            {
              criteria = "AOC Q27G40XMN*";
              status = "enable";
              mode = "2560x1440@180Hz";
              position = "2560,0";
              #adaptiveSync = true;
            }
            {
              criteria = "*VG271U*";
              status = "enable";
              mode = "2560x1440@143.999Hz";
              position = "0,0";
              #position = "2560,0";
              #adaptiveSync = true;
            }
            {
              criteria = "*55R635*";
              status = "disable";
              mode = "2560x1440@120Hz";
              position = "5120,0";
              #adaptiveSync = true;
            }
            {
              criteria = "*SAMSUNG*"; # Dummy display
              status = "disable";
              adaptiveSync = false;
            }
          ];
          exec = [
            "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
            "${pkgs.sway}/bin/swaymsg output DP-1 hdr on"
          ];
        };
  	  }
    ];
  };

  home.file = {
    # Force back to default
    ".config/hypr/displays.lua" = {
      text = ''
        hl.monitor({
            output            = "DP-1",
            mode              = "2560x1440@180",
            position          = "2560x0",
            scale             = 1,
            transform         = 0,
            vrr               = 2,
            bitdepth          = 10,
            cm                = "hdr",
            sdr_eotf          = "auto",
            supports_hdr      = true,
            sdr_min_luminance = 0.0,
            sdr_max_luminance = 203,
            min_luminance     = 0,
            max_luminance     = 1156,
            max_avg_luminance = 1156,
        })

        hl.monitor({
            output              = "DP-2",
            mode                = "2560x1440@144",
            position            = "0x0",
            scale               = 1,
            transform           = 0,
            vrr                 = 2,
            bitdepth            = 10,
            cm                  = "srgb",
            sdr_eotf            = "auto",
            supports_hdr        = false,
            supports_wide_color = false,
        })

        hl.monitor({
            output            = "HDMI-A-1",
            disabled          = true,
            mode              = "2560x1440@120",
            position          = "5120x0",
            scale             = 1,
            transform         = 0,
            vrr               = 0,
            bitdepth          = 10,
            cm                = "srgb",
            sdr_eotf          = "auto",
            supports_hdr      = true,
            sdr_min_luminance = 0.0,
            sdr_max_luminance = 203,
            min_luminance     = 0,
            max_luminance     = 800,
            max_avg_luminance = 1156,
        })

        hl.monitor({
            output            = "DP-3",
            disabled          = true,
            mode              = "2560x1440@120",
            position          = "5120x0",
            scale             = 1,
            transform         = 0,
            vrr               = 2,
            bitdepth          = 10,
            cm                = "srgb",
            sdr_eotf          = "auto",
            supports_hdr      = true,
            sdr_min_luminance = 0.0,
            sdr_max_luminance = 203,
            min_luminance     = 0,
            max_luminance     = 1000,
            max_avg_luminance = 1000,
        })
      '';
    };

    ".config/jay/config.toml" = {
      text = lib.mkAfter ''
        [[outputs]]
        match.connector = "DP-1"
        mode = { width = 2560, height = 1440, refresh-rate = 180.001 }
        scale = 1.0
        x = 2560
        y = 0
        vrr = { mode = "variant1", cursor-hz = 80 }
        transfer-function = "pq"
        color-space = "bt2020"
        blend-space = "linear"
        format = "xrgb2101010"
        name = "primary"
        tearing.mode = "never"
        
        [[outputs]]
        match.connector = "DP-2"
        mode = { width = 2560, height = 1440, refresh-rate = 143.999 }
        scale = 1.0
        x = 0
        y = 0
        vrr = { mode = "variant1", cursor-hz = 80 }
        name = "secondary"
        tearing.mode = "never"
        
        [[outputs]]
        match.connector = "DP-3"
        enabled = false
        mode = { width = 2560, height = 1440, refresh-rate = 120.0 }
        vrr = { mode = "never", cursor-hz = 80 }
        format = "xrgb2101010"
        tearing.mode = "never"
        
        [[outputs]]
        match.connector = "HDMI-A-1"
        enabled = false
        mode = { width = 2560, height = 1440, refresh-rate = 120.0 }
        vrr = { mode = "never", cursor-hz = 80 }
        transfer-function = "pq"
        color-space = "bt2020"
        blend-space = "linear"
        format = "xrgb2101010"
        tearing.mode = "never"
      '';
    };
  };
}
