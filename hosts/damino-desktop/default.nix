# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      ./openrgb
    ];

  networking.hostName = "damino-desktop"; # Define your hostname.
  networking.interfaces.enp10s0.wakeOnLan.enable = true;

  environment.sessionVariables = {
    RADV_DEBUG = "nofastclears"; # Fix for 5700 XT (https://gitlab.freedesktop.org/mesa/mesa/-/issues/6113)
  };
  
  services = {
    apcupsd = {
      enable = true;
      configText = ''
        UPSTYPE usb
        NISIP 127.0.0.1
        ONBATTERYDELAY 6
        BATTERYLEVEL 10
        MINUTES 3
        TIMEOUT 0
        ANNOY 300
        ANNOYDELAY 60
        BEEPSTATE T
      '';
    };
  };
}
