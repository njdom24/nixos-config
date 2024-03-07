{ branch
, qt6Packages
, fetchFromGitHub
, fetchurl
}:

let
  # Fetched from https://api.citra-emu.org/gamedb
  # Please make sure to update this when updating citra!
  compat-list = fetchurl {
    name = "citra-compat-list";
    url = "https://web.archive.org/web/20230807103651/https://api.citra-emu.org/gamedb/";
    hash = "sha256-J+zqtWde5NgK2QROvGewtXGRAWUTNSKHNMG6iu9m1fU=";
  };
in {
  mk7 = qt6Packages.callPackage ./generic.nix rec {
    pname = "citra-mk7";
    #version = "1963";
    version = "2.2";

    src = fetchFromGitHub {
      #owner = "citra-emu";
      owner = "PabloMK7";
      #repo = "citra-nightly";
      repo = "citra";
      #rev = "nightly-${version}";
      rev = "v${version}";
      # hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      sha256 = "sha256-k07BdZr8Y4S8cUDJVnCw4NkeeRJoXfuK0aRx6EJ3bAQ=";
      fetchSubmodules = true;
    };

    inherit branch compat-list;
  };

  #canary = qt6Packages.callPackage ./generic.nix rec {
  #  pname = "citra-canary";
  #  version = "2573";

  #  src = fetchFromGitHub {
  #    owner = "citra-emu";
  #    repo = "citra-canary";
  #    rev = "canary-${version}";
  #    sha256 = "sha256-tQJ3WcqGcnW9dOiwDrBgL0n3UNp1DGQ/FjCR28Xjdpc=";
  #    fetchSubmodules = true;
  #  };

  #  inherit branch compat-list;
  #};
}.${branch}
