# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./common.nix
      ./openrgb
      inputs.chaotic.nixosModules.default
    ];

  networking.hostName = "damino-desktop"; # Define your hostname.
  networking.interfaces.enp10s0.wakeOnLan.enable = true;

  # TODO: Remove in 25.05 in favor of https://github.com/NixOS/nixpkgs/issues/269419
  #chaotic.mesa-git.enable = true;
  hardware = {
    firmware = lib.mkBefore [ pkgs.unstable.linux-firmware ];
    graphics = {
      extraPackages = with pkgs.unstable; [
        amdvlk
      ];
      extraPackages32 = with pkgs.unstable; [
        driversi686Linux.amdvlk
      ];
    };
  };

  programs.steam.gamescopeSession.args = [
  	"-H 1440"
  	"-r 120"
  	"-O HDMI-A-1"
  ];

  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
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
