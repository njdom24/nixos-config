{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "virtual-desktops-only-on-primary";
  version = "master-20250823"; # use date or commit hash

  src = fetchFromGitHub {
    owner = "Ubiquitine";
    repo = "virtual-desktops-only-on-primary";
    rev = "master";
    # Optional: replace with specific commit SHA for stability
    sha256 = "sha256-zC096vsVCyDAEFpASU2gj0qRgWKYR1m9G6hPZL+61Wo=";
  };

  installPhase = ''
    mkdir -p $out/share/kwin/scripts/virtual-desktops-only-on-primary
    cp -r * $out/share/kwin/scripts/virtual-desktops-only-on-primary/
  '';

  meta = with lib; {
    description = "KWin script: switchable virtual desktops on primary only";
    homepage = "https://github.com/Ubiquitine/virtual-desktops-only-on-primary";
    license = licenses.gpl3;
    maintainers = [ ];
  };
}
