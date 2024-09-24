{ inputs, outputs, config, pkgs, lib, ... }:
{
  imports = [
  ];

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  ];

  environment.systemPackages = with pkgs; [
    smartmontools
  ];

  services = {
    smartd = {
      enable = true;
      devices = [
  	    { device = "/dev/disk/by-id/usb-WD_My_Passport_2626_575839324435334152364A43-0:0"; } # /mnt/ext
      ];
    };
  };
}
