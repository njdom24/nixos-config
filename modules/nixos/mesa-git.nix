{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.mesa-git;
in
{
  options.mesa-git = {
    enable = lib.mkEnableOption "Build Mesa from the latest Git HEAD and add to environment";
    global = lib.mkEnableOption "Replace hardware.graphics.package with mesa-git";
  };

  config = let
    libdrm-git = pkgs.libdrm.overrideAttrs (old: let
      parts = lib.splitString "." old.version;
      major = lib.toInt (builtins.elemAt parts 0);
      minor = lib.toInt (builtins.elemAt parts 1);
      patch = lib.toInt (builtins.elemAt parts 2);
    in {
      src = inputs.libdrm-git;
      version =
        "${toString major}.${toString (minor + 2)}.${toString patch}-git-${inputs.libdrm-git.rev}";
    });

    libdrm32-git = pkgs.pkgsi686Linux.libdrm.overrideAttrs (old: let
      parts = lib.splitString "." old.version;
      major = lib.toInt (builtins.elemAt parts 0);
      minor = lib.toInt (builtins.elemAt parts 1);
      patch = lib.toInt (builtins.elemAt parts 2);
    in {
      src = inputs.libdrm-git;
      version =
        "${toString major}.${toString (minor + 2)}.${toString patch}-git-${inputs.libdrm-git.rev}";
    });

    mesa-git = (pkgs.mesa.override {
      libdrm = libdrm-git;
    }).overrideAttrs (old: {
      src = inputs.mesa-git;
      version = "git-${inputs.mesa-git.rev}";

      patches = (old.patches or []) ++ [
        (pkgs.fetchpatch {
          url = "https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/39551.patch";
          hash = "sha256-phqyDnkBFgpEgAsWPxR4aQ9TikgIeI1NWEjXP1dqQvI=";
        })
      ];
    });

    mesa32-git = (pkgs.driversi686Linux.mesa.override {
      libdrm = libdrm32-git;
    }).overrideAttrs (old: {
      src = inputs.mesa-git;
      version = "32-git-${inputs.mesa-git.rev}";
    });

  in lib.mkIf cfg.enable {
    environment.variables.MESA_GIT =
      lib.concatStringsSep ":" [
        "${mesa-git}/share/vulkan/icd.d/radeon_icd.x86_64.json"
        "${mesa32-git}/share/vulkan/icd.d/radeon_icd.i686.json"
      ];

    hardware.graphics.package   = lib.mkIf cfg.global mesa-git;
    hardware.graphics.package32 = lib.mkIf cfg.global mesa32-git;
  };
}

