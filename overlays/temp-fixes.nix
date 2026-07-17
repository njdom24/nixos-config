final: prev: let
  handbrakeNixpkgs = import (prev.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "00c33702baa387c313bcfa919ef1c9565ec45c20"; # https://github.com/NixOS/nixpkgs/pull/541043/changes
    hash = "sha256-eUMGcLcT4qk0lMexokWJjKJbw+wwrNQ6y46TArgN89Y=";
  }) {
    inherit (prev) system config;
  };
in {
  handbrake = handbrakeNixpkgs.handbrake;
}
