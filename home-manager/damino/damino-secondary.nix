{ inputs, pkgs, lib, ... }: {
  imports = [ ./damino-desktop.nix ];

  services = {
    mako.settings.output = lib.mkForce "DP-2";
    swaync.settings = {
      notification-window-preferred-output = lib.mkForce "DP-2";
      positionX = lib.mkForce "right";
    };
  };

  home.file = {
    # Force back to default
    ".config/hypr/hm/displays.conf" = lib.mkForce {
      text = ''
        monitorv2 {
          output = DP-1
          mode = 2560x1440@180
           position = 2560x0
           scale = 1
           transform = 0
           supports_hdr = 1
           vrr = 2
           sdr_min_luminance = 0.005
           sdr_max_luminance = 260
           min_luminance = 0.005
           max_luminance = 1156
           max_avg_luminance = 1156
           bitdepth = 10
           cm = srgb
        }
        
        monitorv2 {
          output = DP-2
          mode = 2560x1440@144
          position = 0x0
          scale = 1
          transform = 0
          vrr = 0
          bitdepth = 10
          cm = srgb
        }

        monitor = DP-3, disable
        monitor = HDMI-A-1, disable
      '';
    };
  };
}
