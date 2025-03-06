# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration-secondary.nix
      ./common.nix
    ];

  networking.hostName = "damino-secondary"; # Define your hostname.
  networking.interfaces.enp4s0.wakeOnLan.enable = true;

  environment.sessionVariables = {
    RADV_DEBUG = "nofastclears"; # Fix for 5700 XT (https://gitlab.freedesktop.org/mesa/mesa/-/issues/6113)
  };

  environment.systemPackages = with pkgs; [
  ];
}
