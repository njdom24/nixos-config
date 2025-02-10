# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [
    ];

  services = {
    hardware.openrgb = {
      enable = true;
      package = pkgs.openrgb-with-all-plugins;
    };
  };

  systemd.services.openrgb-pre-suspend = {
    description = "Set OpenRGB to static black before suspend or shutdown";
    wantedBy = [ "poweroff.target" "halt.target" "reboot.target" "sleep.target" "suspend.target" ];
    before = [ "shutdown.target" "sleep.target" "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --mode static --color 000000";
    };
  };

  systemd.services.openrgb-post-resume = {
    description = "Reload OpenRGB profile after resume";
    wantedBy = [ "default.target" "post-resume.target" "suspend.target" ];
    after = [ "suspend.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --profile ${./Profile.orp}";
    };
  };
}
