{ inputs, pkgs, lib, ... }: {
  imports = [ ./damino-desktop.nix ];

  services = {
    mako.output = lib.mkForce "HDMI-A-1";
  };
}
