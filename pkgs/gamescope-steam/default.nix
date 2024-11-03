{ lib, stdenv, pkgs, ... }:

stdenv.mkDerivation rec {
  pname = "gamescope-steam-desktop";
  version = "1.0"; # You can set this to any version or keep it as is

  # Use a dummy source to bypass the unpack phase
  src = null;

  # Skip the unpackPhase
  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/gamescope-steam.desktop <<EOF
    [Desktop Entry]
    Name=Steam (Gamescope)
    Comment=Launch Steam via Gamescope
    Exec=steam-gamescope
    Icon=steam
    Type=Application
    Categories=Game;
    EOF
  '';
}
