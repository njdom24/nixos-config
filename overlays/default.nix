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
    gamescope = inputs.chaotic.packages.${prev.system}.gamescope_git.overrideAttrs (oldAttrs: {
      # https://github.com/ValveSoftware/gamescope/issues/1622#issuecomment-2508182530
      NIX_CFLAGS_COMPILE = ["-fno-fast-math"];

      # https://github.com/ValveSoftware/gamescope/issues/1604#issuecomment-2603198783
      patches = (oldAttrs.patches or []) ++ [
        ../patches/gamescope-crash-fix.patch
        ../patches/gamescope-hdr-sway-fix.patch
      ];
    });

    mangohud = inputs.chaotic.packages.${prev.system}.mangohud_git;

    # sway pinned to PR #8922 state
    sway-unwrapped = prev.sway-unwrapped.overrideAttrs (old: {
      src = prev.fetchFromGitHub {
        owner = "poisotf";
        repo  = "sway";
        rev   = "4b2643e0a8e9ed67c62572e6cfb6c9b97e8d7568";  # use the branch name from the fork
        sha256 = "sha256-ss0ctrinia/QNgwvwnz7MBvZdIuG27SEWdgEwm4wrMw=";
      };

      buildInputs = (old.buildInputs or []) ++ [ inputs.chaotic.packages.${prev.system}.wlroots_git ];
    });

    xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
      version = "0.8.0";
      src = prev.fetchFromGitHub {
        owner = "emersion";
        repo  = "xdg-desktop-portal-wlr";
        rev   = "v0.8.0";
        sha256 = "sha256-TAWrDH6kud4eXFJvfihImuEFm2uTOaqAOatG+7JmaEM=";
      };
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  legacy-packages = final: _prev: {
    legacy = import inputs.nixpkgs-legacy {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
