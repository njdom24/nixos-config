# This file defines overlays
{ inputs, ...}: let addIfMissing = existing: p: if builtins.any (x: x == p) existing then [] else [p];
in {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final; inputs = inputs;};

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
    gamescope = prev.gamescope.overrideAttrs (old: let
    #gamescope = prev.gamescope.overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [
        ../patches/gamescope-crash-fix.patch
        ../patches/gamescope-hdr-sway-fix.patch
      ];
      #addIfMissing = p: if builtins.any (x: x == p) existing then [] else [p];
    in rec {
      NIX_CFLAGS_COMPILE = ["-fno-fast-math"];
      #patches = existing ++ builtins.concatMap addIfMissing newPatches;
       patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    # sway pinned to PR #8922 state
    sway-unwrapped = prev.sway-unwrapped.overrideAttrs (old: {
      src = inputs.sway-git;
      buildInputs = (old.buildInputs or []) ++ [(
        prev.wlroots_0_19.overrideAttrs (old: let
          existing = old.patches or [];
          newPatches = [
            ../patches/wlroots-no-srgb-eotf.patch
          ];
        in {
          src = inputs.wlroots-git;
          patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
        })
      )];
    });

    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        #(prev.fetchpatch {
        #  url = "https://patch-diff.githubusercontent.com/raw/hyprwm/Hyprland/pull/12127.patch";
        #  sha256 = "sha256-auQhLiP5cIDSYXbD/6/Im7CbeguhaZf5xe1JGCsM9O0=";
        #})
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
