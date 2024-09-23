{ config, pkgs, ... }:

let
  composeServices = [
    { name = "flaresolverr"; file = ./flaresolverr.yaml; }
    { name = "suwayomi"; file = ./suwayomi.yaml; }
  ];
in
{
  systemd.services = builtins.listToAttrs (map (service: {
    name = service.name;
    value = {
      description = "Docker Compose ${service.name}";
      after = [ "docker.service" ];
      wants = [ "docker.service" ];
      serviceConfig = {
        WorkingDirectory = "/srv/docker/${service.name}";
        ExecStart = "${pkgs.docker}/bin/docker compose -f ${service.file} up";
        ExecStop = "${pkgs.docker}/bin/docker compose -f ${service.file} down";
        Restart = "on-failure";
        Type = "simple";
      };
      wantedBy = [ "multi-user.target" ];
    };
  }) composeServices);
}
