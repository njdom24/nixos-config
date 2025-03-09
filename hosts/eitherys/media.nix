{ inputs, outputs, config, pkgs, lib, ... }:
let
  # https://github.com/NixOS/nixpkgs/issues/360592#issuecomment-2513490613
  # Workaround for Sonarr breakage in 24.05. Remove ASAP 
  insecure-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "dotnet-runtime-wrapped-6.0.36"
        "aspnetcore-runtime-6.0.36"
        "aspnetcore-runtime-wrapped-6.0.36"
        "dotnet-sdk-6.0.428"
        "dotnet-sdk-wrapped-6.0.428"
      ];
    };
  };
in
{
  imports = [
  	./containers
  ];

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  ];

  environment.systemPackages = with pkgs; [
  ];

  hardware.graphics = {
  	enable = true;
  	extraPackages = with pkgs; [
  	  vpl-gpu-rt

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
      package = insecure-unstable.sonarr;
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

    bazarr = {
      enable = true;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";
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

  # Create /tmp/transcodes directory before Jellyfin starts as the jellyfin user
  systemd.services.jellyfin-transcodes-directory = {
    description = "Create temporary transcode directory for Jellyfin";
    wantedBy = [ "multi-user.target" ];
    before = [ "jellyfin.service" ];

    serviceConfig = {
      User = config.services.jellyfin.user;
      Group = config.services.jellyfin.group;
      ExecStart = ''
        ${pkgs.coreutils}/bin/mkdir -p /tmp/transcodes
      '';
    };
  };
}
