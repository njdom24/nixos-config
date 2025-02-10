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
    description = "Set OpenRGB to static black before suspend";
    wantedBy = [ "halt.target" "sleep.target" "suspend.target" ];
    before = [ "sleep.target" "suspend.target" ];
    partOf = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "20s";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --mode static --color 000000";
    };
  };

  systemd.services.openrgb-post-resume = {
    description = "Reload OpenRGB profile after resume";
    wantedBy = [ "default.target" "post-resume.target" "suspend.target" ];
    after = [ "openrgb.service" "suspend.target" ];
    requires = [ "openrgb.service" ];
    partOf = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "10s";
      ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.openrgb}/bin/openrgb --profile ${./Profile.orp}'";
    };
  };

  systemd.services.openrgb = {
    requires = [ "openrgb-pre-suspend.service" ]; # Ensure it runs before shutting down
    wantedBy = [ "poweroff.target" "reboot.target" ];
    before = [ "shutdown.target" "poweroff.target" "reboot.target" ]; # Guarantees the pre-shutdown service runs first
    serviceConfig = {
      TimeoutStopSec = "20s";
      ExecStartPost = "${pkgs.openrgb}/bin/openrgb --profile ${./Profile.orp}";
      ExecStop = "${pkgs.openrgb}/bin/openrgb --mode static --color 000000";
    };
  };
  
}
