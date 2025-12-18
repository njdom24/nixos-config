{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.mesa-git;
in
{
  options.mesa-git = {
    enable = lib.mkEnableOption "Build Mesa from the latest Git HEAD";
  };

  config = lib.mkIf cfg.enable {
    environment.variables.MESA_GIT =
      let
        mesa-git = pkgs.mesa.overrideAttrs (_: {
          src = inputs.mesa-git;
          # Compute unique version string from src
          version = "git-${inputs.mesa-git.rev}";
        });

        mesa32-git = pkgs.driversi686Linux.mesa.overrideAttrs (_: {
          src = inputs.mesa-git;
          # Compute unique version string from src
          version = "32-git-${inputs.mesa-git.rev}";
        });
      in lib.concatStringsSep ":" [
        "${mesa-git}/share/vulkan/icd.d/radeon_icd.x86_64.json"
        "${mesa32-git}/share/vulkan/icd.d/radeon_icd.i686.json"
      ];
  };
}
