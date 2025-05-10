{ inputs, pkgs, lib, ... }: {
  imports = [ ./damino-desktop.nix ];

  services = {
    mako.settings.output = lib.mkForce "HDMI-A-1";
  };
}
