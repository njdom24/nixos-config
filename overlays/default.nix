# This file defines overlays
{ inputs, ...}: let addIfMissing = existing: p: if builtins.any (x: x == p) existing then [] else [p];
in {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final; inputs = inputs;};

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: let
    wlrootsPatched = prev.wlroots_0_20.overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [
        (prev.fetchpatch {
          url = "https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/5143.diff";
          sha256 = "sha256-At3PsGV5KChIuNdGgfht/r7XydKiIqDahbeGFWM1Rok=";
        })
        #../patches/wlr-scrgb.patch
        ../patches/wlr-hdr-hack.patch
      ];
    in {
      src = inputs.wlroots-git;
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    wlrootsPatchedStable = prev.wlroots_0_20.overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [
        (prev.fetchpatch {
          url = "https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/5143.diff";
          sha256 = "sha256-At3PsGV5KChIuNdGgfht/r7XydKiIqDahbeGFWM1Rok=";
        })
        (prev.fetchpatch {
          url = "https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/5361.diff";
          sha256 = "sha256-J0Cr+slZP6EeDKIdGzY/mKA6y840i/KIvjgbgXs/zP0=";
        })
        #../patches/wlr-scrgb.patch
        ../patches/wlr-hdr-hack.patch
      ];
    in {
      # no `src` override here — keep upstream 0.20 release source
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });
  in (import ./temp-fixes.nix final prev) // {
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
        (prev.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/ValveSoftware/gamescope/pull/2049.patch";
          sha256 = "sha256-g/WILRVbuJhrNsQNlQL3nYO8Lz4YdYpuaUf7jN/yYgg=";
        })
        (prev.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/ValveSoftware/gamescope/pull/2100.patch";
          sha256 = "sha256-dbM7kOLAa2MthKYgMLdt/YA1IzSStFapyQDvyq+VnF4=";
        })
        (prev.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/ValveSoftware/gamescope/pull/2134.patch";
          sha256 = "sha256-xEAtT8evRoDgnDlgIDknHkhjmIQ0mPA93hyd5wei75I=";
        })
        ../patches/gamescope-cursor-vrr.patch
      ];
      #addIfMissing = p: if builtins.any (x: x == p) existing then [] else [p];
    in rec {
      NIX_CFLAGS_COMPILE = ["-fno-fast-math"];
      #src = inputs.gamescope-git;
      #patches = existing ++ builtins.concatMap addIfMissing newPatches;
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    # sway pinned to PR #8922 state
    sway-unwrapped = prev.sway-unwrapped.overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [ ../patches/sway-scrgb.patch ];
    in {
      src = inputs.sway-git;
      buildInputs = (old.buildInputs or []) ++ [ wlrootsPatched ];
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    jay = (inputs.jay.packages.${prev.stdenv.hostPlatform.system}.jay).overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [
        # ContainerBorders::FullSmart
        (prev.fetchpatch {
          url = "https://github.com/mahkoh/jay/pull/1147.diff";
          sha256 = "sha256-zlDmabzajhe/k+peKbGJaVfBn3UjxXW2yataRhGerNs=";
        })
      ];
    in {
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    mango = let
      scenefxFlake = inputs.mangowm.inputs.scenefx.packages.${final.stdenv.hostPlatform.system}.default;

      scenefxPatched = let
        existing = scenefxFlake.buildInputs or [];
        withoutWlroots = builtins.filter
          (p: !(final.lib.hasInfix "wlroots" (p.pname or p.name or "")))
          existing;
      in scenefxFlake.overrideAttrs (old: {
        buildInputs = withoutWlroots ++ [ wlrootsPatchedStable ];
      });

      mangoBase = final.callPackage "${inputs.mangowm}/nix" {
        scenefx = scenefxPatched;
        wlroots_0_20 = wlrootsPatchedStable;
      };
    in mangoBase.overrideAttrs (old: let
      existing = old.patches or [];
      newPatches = [ ../patches/mango-scrgb.patch ];
    in {
      patches = existing ++ builtins.concatMap (addIfMissing existing) newPatches;
    });

    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
      ];
    });
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

    xwayland-satellite = inputs.xwayland-satellite.packages.${prev.stdenv.hostPlatform.system}.xwayland-satellite;

    moonlight-qt = prev.moonlight-qt.overrideAttrs (old: {
      src = inputs.moonlight-qt-git;
      patches = [];
    });
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
