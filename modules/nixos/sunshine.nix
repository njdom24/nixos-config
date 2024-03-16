{ config, lib, pkgs, ... }:
# https://github.com/devusb/nix-config/blob/18913d6eb9a374b3c46a4490637506ca5bc07337/modules/nixos/sunshine.nix
with lib;

let

  cfg = config.services.sunshine;

in

{
  options = {

    services.sunshine = {
      enable = mkEnableOption (mdDoc "Sunshine");
      package = mkPackageOption pkgs "sunshine" { };
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages = [
      cfg.package
    ];

    security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${cfg.package}/bin/sunshine";
    };

    systemd.user.services.sunshine = {
      description = "sunshine";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${config.security.wrapperDir}/sunshine";
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 47984 47989 48010 ];
      allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
    };

  };
}
