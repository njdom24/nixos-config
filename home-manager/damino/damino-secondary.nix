{ inputs, pkgs, lib, ... }: {
  imports = [ ./damino-desktop.nix ];

  services = {
    mako.settings.output = lib.mkForce "DP-2";
    swaync.settings = {
      notification-window-preferred-output = lib.mkForce "DP-2";
      positionX = lib.mkForce "right";
    };
  };

  programs = {
    noctalia.settings = {
      notifications = {
        monitors = [ "DP-2" ];
        position = "top_right";
      };
    };
  };

  home.file = {
    # Force back to default
    ".config/hypr/displays.lua" = lib.mkForce {
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
            vrr                 = 0,
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
  };
}
