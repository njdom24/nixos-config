# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{ pkgs, ...}: {
  # example = pkgs.callPackage ./example { };
  xcursor-pro = pkgs.callPackage ./xcursor-pro { };
  citra-mk7 = pkgs.unstable.lime3ds.overrideAttrs (final: prev: {
    pname = "citra";
    version = "r5115f64"; # Git release version

    src = pkgs.fetchFromGitHub {
      owner = "PabloMK7";
      repo = "citra";
      rev = "${final.version}";
      sha256 = "sha256-7l32wBJLunp/wjUc02uiXS8XRkJkm+ckLUQqWUKIHRQ=";
      fetchSubmodules = true;
    };

    postInstall = builtins.replaceStrings ["lime3ds"] ["citra"] ( builtins.replaceStrings ["lime3ds-cli"] ["citra"] ( builtins.replaceStrings ["lime3ds-gui"] ["citra-qt"] prev.postInstall ) );
    meta.mainProgram = builtins.replaceStrings ["lime3ds"] ["citra"] ( builtins.replaceStrings ["lime3ds-cli"] ["citra"] ( builtins.replaceStrings ["lime3ds-gui"] ["citra-qt"] prev.meta.mainProgram ) );
  });
}
