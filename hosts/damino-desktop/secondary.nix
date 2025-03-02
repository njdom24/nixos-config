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
  #  RADV_DEBUG = "nofastclears"; # Fix for 5700 XT (https://gitlab.freedesktop.org/mesa/mesa/-/issues/6113)
  };

  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = false;
      finegrained = false;
    };
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {                                            
        version = "570.124.04"; # use new 570 drivers                                                            
        sha256_64bit = "sha256-G3hqS3Ei18QhbFiuQAdoik93jBlsFI2RkWOBXuENU8Q=";                                   
        openSha256 = "sha256-DuVNA63+pJ8IB7Tw2gM4HbwlOh1bcDg2AN2mbEU9VPE=";                                     
        settingsSha256 = "sha256-9rtqh64TyhDF5fFAYiWl3oDHzKJqyOW3abpcf2iNRT8=";                                 
        usePersistenced = false;                                                                                
    };
  };
}
