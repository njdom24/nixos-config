{ config, lib, pkgs, ... }:

# Define the function to substitute strings in a YAML file (no default args)
let
  dockerPath = "/srv/docker";
  defaultSearchStrings = [ "REL_PATH" "MEDIA_UID" "MEDIA_GID" ];
  defaultReplaceStrings = [ "${dockerPath}" "${toString config.users.users.jellyfin.uid}" "${toString config.users.groups.jellyfin.gid}" ];

  substituteYaml = { file, searchStrings, replaceStrings }: 
    pkgs.writeTextFile {
      name = "${builtins.baseNameOf file}-substituted.yaml";  # Create a new name based on the original file
      text = builtins.replaceStrings (defaultSearchStrings ++ searchStrings) 
                                      (defaultReplaceStrings ++ replaceStrings) 
                                      (builtins.readFile file);
    };

  # Function to determine the appropriate file for Exec commands
  getFileForExec = service: 
    if (service ? searchStrings && service ? replaceStrings)
      then substituteYaml { file = service.file; searchStrings = service.searchStrings; replaceStrings = service.replaceStrings; }
      else substituteYaml { file = service.file; searchStrings = []; replaceStrings = []; };

  # Function to get the name without any extension
  nameWithoutExtension = file: let
    baseName = builtins.baseNameOf file;
    parts = lib.strings.splitString "." baseName; # Use lib.strings.splitString
  in
    if builtins.length parts > 1
      then builtins.concatStringsSep "." (lib.lists.take (builtins.length parts - 1) parts)
      else baseName; # Return the base name if no extension

  # Define the services
  composeServices = [
    # If file requires replacements
    #{
    #  file = ./flaresolverr.yaml;
    #  searchStrings = [ "OLD_STRING" ];   # Define the strings to replace
    #  replaceStrings = [ "NEW_STRING" ];  # Define the replacements
    #}
    { file = ./gluetun.yaml; }
    { file = ./romm.yaml; }
    { file = ./kavita.yaml; }
    { file = ./lazylibrarian.yaml; }
    { file = ./flaresolverr.yaml; }
    { file = ./qbittorrent.yaml; }
    { file = ./suwayomi.yaml; }
  ];
in
{
  # Generate systemd services for each docker-compose file
  systemd.services = builtins.listToAttrs (map (service:
  let
    serviceName = nameWithoutExtension service.file;
    composeFile = getFileForExec service;
    envFile = "/var/secrets/${serviceName}";
  in
    {
      name = serviceName;  # Use the derived name
      value = {
        description = "Docker Compose ${serviceName}";
        after = [ "docker.service" ];
        wants = [ "docker.service" ];
        serviceConfig = {
          TimeoutStartSec = "60min";
          ExecStartPre = "${pkgs.docker}/bin/docker compose -f ${composeFile} pull";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker compose -f ${composeFile} $(test -f ${envFile} && echo --env-file ${envFile}) up'";
          ExecStop = "${pkgs.docker}/bin/docker compose -f ${composeFile} down";
          Restart = "on-failure";
          Type = "simple";
        };
        wantedBy = [ "multi-user.target" ];
      };
    }
  ) composeServices);

  networking.firewall.allowedTCPPorts = [
    4568 # suwayomi
    5000 # kavita
    5299 # lazylibrarian
    6788 # sabnzbd
    8597 # romm
    43000 # qbt
  ];
}

