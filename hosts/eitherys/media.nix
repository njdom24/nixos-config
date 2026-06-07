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

  hardware.graphics = {
  	enable = true;
  	extraPackages = with pkgs; [
  	  vpl-gpu-rt

  	  # intel-media-sdk # Deprecated
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

    bazarr = {
      enable = true;
      openFirewall = true;
      user = "jellyfin";
      group = "jellyfin";
    };

    sabnzbd = let
      defaultCategory = {
        order = 0;
        pp = "";
        script = "Default";
        dir = "";
        newzbin = "";
        priority = -100;
      };
    in {
      enable = true;
      user = "jellyfin";
      group = "jellyfin";
      settings = {
        misc.port = 6788;
        categories =
          {
            "*" = {
              name = "*";
              order = 0;
              pp = 3;
              script = "None";
              dir = "";
              newzbin = "";
              priority = 0;
            };
          }
          // builtins.listToAttrs (
            map (name: {
              inherit name;
              value = defaultCategory // { inherit name; };
            }) [
              "movies"
              "tv"
              "audio"
              "software"
              "books"
            ]
          );
      };
      secretFiles = [ "/var/secrets/sabnzbd" ];
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
