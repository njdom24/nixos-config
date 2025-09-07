{ inputs, pkgs, lib, ... }: {
  imports = [ ./damino-desktop.nix ];

  # wayland.windowManager.hyprland.settings.env = [ "AQ_DRM_DEVICES,/dev/dri/card0" ];

  services = {
    mako.settings.output = lib.mkForce "HDMI-A-1";
    swaync.settings.notification-window-preferred-output = lib.mkForce "HDMI-A-1";
  };

  home.file = {
    # Force back to default
    ".config/hypr/hm/displays.conf" = lib.mkForce {
      text = ''
        monitor=,preferred,auto,auto
        exec = timeout 10 kanshi &
      '';
    };
  };
}
