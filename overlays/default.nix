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
        ../patches/gamescope-sway-fix.patch
      ];
    });

    mangohud = inputs.chaotic.packages.${prev.system}.mangohud_git;

    sunshine = prev.sunshine.overrideAttrs (oldAttrs: rec {
      src = prev.fetchFromGitHub {
      owner = "LizardByte";
      repo = "Sunshine";
      rev = "958d783d9431f029719dafd9cd451fb5397476b2"; # desired commit
      hash = "sha256-J4llOaYk93lgI4RQZx6UeywUF3LcGIv/foMSbAvS+G4="; # update via `nix-prefetch`
      fetchSubmodules = true;
    };

      postPatch = ''
      # remove upstream dependency on systemd and udev
      substituteInPlace cmake/packaging/linux.cmake \
        --replace-fail 'find_package(Systemd)' "" \
        --replace-fail 'find_package(Udev)' ""

      # don't look for npm since we build webui separately
      substituteInPlace cmake/targets/common.cmake \
        --replace-fail 'find_program(NPM npm REQUIRED)' ""

      substituteInPlace packaging/linux/dev.lizardbyte.app.Sunshine.desktop \
        --subst-var-by PROJECT_NAME 'Sunshine' \
        --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
        --subst-var-by SUNSHINE_DESKTOP_ICON 'sunshine' \
        --subst-var-by CMAKE_INSTALL_FULL_DATAROOTDIR "$out/share" \
        --replace-fail '/usr/bin/env systemctl start --u sunshine' 'sunshine'

      substituteInPlace packaging/linux/sunshine.service.in \
        --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
        --subst-var-by SUNSHINE_EXECUTABLE_PATH $out/bin/sunshine \
        --replace-fail '/bin/sleep' '${prev.coreutils}/bin/sleep'
      '';

      postInstall = ''
        install -Dm644 ../packaging/linux/dev.lizardbyte.app.Sunshine.desktop $out/share/applications/dev.lizardbyte.app.Sunshine.desktop
      '';
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
