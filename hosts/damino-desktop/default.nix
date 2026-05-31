# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      ./displays.nix
      ./openrgb
    ];

  networking.hostName = "damino-desktop"; # Define your hostname.
  networking.interfaces.enp10s0.wakeOnLan.enable = true;

  environment.sessionVariables = {
    # https://github.com/Etaash-mathamsetty/Proton/blob/em-10/docs/FSR4.md
    PROTON_FSR4_UPGRADE = 1;
    FSR4_UPGRADE = 1;
  };

  #mesa-git = {
  #  enable = true;
  #  global = true;
  #};

  programs.steam.gamescopeSession.args = [
  	"-H 1440"
  	"-r 144"
  	"-O HDMI-A-1"
  ];
  
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
  system.stateVersion = "26.05";
}
