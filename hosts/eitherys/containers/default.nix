{ lib, pkgs, ... }:

# Define the function to substitute strings in a YAML file (no default args)
let
  substituteYaml = { file, searchStrings, replaceStrings }: 
    pkgs.writeTextFile {
      name = "${builtins.baseNameOf file}-substituted.yaml";  # Create a new name based on the original file
      text = builtins.replaceStrings searchStrings replaceStrings (builtins.readFile file);
    };

  composeServices = [
    # If file requires replacements
    #{
    #  name = "flaresolverr";
    #  file = substituteYaml {
    #    file = ./flaresolverr.yaml;
    #    searchStrings = [ "OLD_STRING" ];   # Define the strings to replace
    #    replaceStrings = [ "NEW_STRING" ];  # Define the replacements
    #  };
    #}

    { name = "flaresolverr"; file = ./flaresolverr.yaml; }
    { name = "suwayomi"; file = ./suwayomi.yaml; }
  ];
in
{
  # Generate systemd services for each docker-compose file
  systemd.services = builtins.listToAttrs (map (service: {
    name = service.name;
    value = {
      description = "Docker Compose ${service.name}";
      after = [ "docker.service" ];
      wants = [ "docker.service" ];
      serviceConfig = {
        WorkingDirectory = "/srv/docker/${service.name}";
        TimeoutStartSec = "60min";
        ExecStartPre = "${pkgs.docker}/bin/docker compose -f ${service.file} pull";
        ExecStart = "${pkgs.docker}/bin/docker compose -f ${service.file} up";
        ExecStop = "${pkgs.docker}/bin/docker compose -f ${service.file} down";
        Restart = "on-failure";
        Type = "simple";
      };
      wantedBy = [ "multi-user.target" ];
    };
  }) composeServices);
}
