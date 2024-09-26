{ inputs, outputs, config, pkgs, lib, ... }:
{
  imports = [
  	./containers
  ];

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  ];

  environment.systemPackages = with pkgs; [
  ];

  hardware.opengl = {
  	enable = true;
  	extraPackages = with pkgs; [
  	  # vpl-gpu-rt After 24.10 releases
  	  onevpl-intel-gpu

  	  intel-media-sdk
  	  intel-compute-runtime
  	  intel-media-driver
  	  libvdpau-va-gl
  	];
  };
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; }; # Force intel-media-driver for QSV

  users = {
    users.jellyfin = {
  	  isSystemUser = true;
  	  description = "Media";
  	  uid = 965;
  	  group = "jellyfin";
  	  createHome = true;
  	  home = "/home/jellyfin";
  	  shell = pkgs.bash;
  	  extraGroups = [
  	   "video"
  	   "audio"
  	   "render"
  	  ];
    };
    groups.jellyfin = {
      gid = 998;
    };
  };


  services = {
    sonarr = {
      enable = true;
      package = pkgs.unstable.sonarr;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";
    };

    radarr = {
      enable = true;
      package = pkgs.unstable.radarr;
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

    jellyfin = {
      enable = true;
      package = pkgs.unstable.jellyfin;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";
      dataDir = "/srv/media/jellyfin";
      configDir = "/srv/media/jellyfin/config";
      cacheDir = "/srv/media/jellyfin/cache";
      logDir = "/srv/media/jellyfin/log";
    };
  };
}
