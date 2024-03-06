# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: {
  # example = pkgs.callPackage ./example { };
  xcursor-pro = pkgs.callPackage ./xcursor-pro { };
  citra-mk7 = pkgs.callPackage ./citra { branch = "mk7"; };
}
