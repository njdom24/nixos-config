{ config, lib, pkgs, ... }:

# Define the function to substitute strings in a YAML file (no default args)
let
  defaultSearchStrings = [ "MEDIA_UID" "MEDIA_GID" ];
  defaultReplaceStrings = [ "${toString config.users.users.jellyfin.uid}" "${toString config.users.groups.jellyfin.gid}" ];

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

    { file = ./flaresolverr.yaml; }
    { file = ./qbittorrent.yaml; }
    { file = ./suwayomi.yaml; }
    { file = ./kavita.yaml; }
  ];
in
{
  # Generate systemd services for each docker-compose file
  systemd.services = builtins.listToAttrs (map (service:
  let
    dockerPath = "/srv/docker";
    serviceName = nameWithoutExtension service.file;
    composeFile = getFileForExec service;
    envFile = "${dockerPath}/${serviceName}/.env";
  in
    {
      name = serviceName;  # Use the derived name
      value = {
        description = "Docker Compose ${serviceName}";
        after = [ "docker.service" ];
        wants = [ "docker.service" ];
        serviceConfig = {
          WorkingDirectory = "${dockerPath}/${serviceName}";
          TimeoutStartSec = "60min";
          ExecStartPre = [
            "${pkgs.bash}/bin/bash -c 'test -f ${envFile} || touch ${envFile}'"
            "${pkgs.docker}/bin/docker compose -f ${composeFile} pull"
          ];
          ExecStart = "${pkgs.docker}/bin/docker compose -f ${composeFile} --env-file ${envFile} up";
          ExecStop = "${pkgs.docker}/bin/docker compose -f ${composeFile} down";
          Restart = "on-failure";
          Type = "simple";
        };
        wantedBy = [ "multi-user.target" ];
      };
    }
  ) composeServices);
}

