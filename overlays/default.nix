# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    #mesa = prev.mesa.overrideAttrs (oldAttrs: {
    #  patches = (oldAttrs.patches or []) ++ [
    #    #./my-mesa-fix.patch
    #  ];
    #});
    gamescope = inputs.chaotic.packages.${prev.stdenv.hostPlatform.system}.gamescope_git.overrideAttrs (oldAttrs: {
      # https://github.com/ValveSoftware/gamescope/issues/1622#issuecomment-2508182530
      NIX_CFLAGS_COMPILE = ["-fno-fast-math"];

      # https://github.com/ValveSoftware/gamescope/issues/1604#issuecomment-2603198783
      patches = (oldAttrs.patches or []) ++ [
        ../patches/gamescope-crash-fix.patch
        ../patches/gamescope-hdr-sway-fix.patch
      ];
    });

    mangohud = inputs.chaotic.packages.${prev.stdenv.hostPlatform.system}.mangohud_git;

    # sway pinned to PR #8922 state
    sway-unwrapped = prev.sway-unwrapped_git.overrideAttrs (old: {
      #src = prev.fetchFromGitHub {
      #  owner = "poisotf";
      #  repo  = "sway";
      #  rev   = "4b2643e0a8e9ed67c62572e6cfb6c9b97e8d7568";  # use the branch name from the fork
      #  sha256 = "sha256-ss0ctrinia/QNgwvwnz7MBvZdIuG27SEWdgEwm4wrMw=";
      #};

      buildInputs = (old.buildInputs or []) ++ [ inputs.chaotic.packages.${prev.stdenv.hostPlatform.system}.wlroots_git ];
      
      patches = let
        existing = old.patches or [];
        myPatch = ../patches/sway-no-srgb-eotf.patch;
        alreadyExists = builtins.any (p: p == myPatch) existing;
      in
        if alreadyExists then existing else existing ++ [ myPatch ];
    });

    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        (prev.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/hyprwm/Hyprland/pull/12204.patch";
          sha256 = "sha256-R/EoC65SEIya8RxUKzmKOpV1CIyCqRKikrz1zxgDNbU=";
        })
        (prev.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/hyprwm/Hyprland/pull/12127.patch";
          sha256 = "sha256-auQhLiP5cIDSYXbD/6/Im7CbeguhaZf5xe1JGCsM9O0=";
        })
      ];
    });
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

    xwayland-satellite = inputs.xwayland-satellite.packages.${prev.stdenv.hostPlatform.system}.xwayland-satellite;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  legacy-packages = final: _prev: {
    legacy = import inputs.nixpkgs-legacy {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}
