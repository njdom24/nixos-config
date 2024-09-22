{ inputs, outputs, config, pkgs, lib, ... }:
{
  imports = [
  	
  ];

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  ];

  environment.systemPackages = with pkgs; [
  ];

  services = {
    sonarr = {
      enable = true;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";
    };

    radarr = {
      enable = true;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";	
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
    };

    sabnzbd = {
      enable = true;
      user = "jellyfin";
      group = "jellyfin";
    };
  };

  networking.firewall.allowedTCPPorts = [
    4568 4580 # suwayomi
    5000 # kavita
  	6788 # SABnzbd
  	43000 # qbt
  ];
}
