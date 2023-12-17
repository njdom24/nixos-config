{ lib
, fetchzip
, stdenv
}:

let
  _src = variant: suffix: hash: fetchzip ({
    name = variant;
    url = "https://github.com/ful1e5/XCursor-pro/releases/download/v${version}/${variant}.${suffix}";
    hash = hash;
  } // (lib.optionalAttrs (suffix == "zip") { stripRoot = false; }));

  version = "2.0.1";
  srcs = [
    (_src "XCursor-Pro-Light" "tar.gz" "sha256-K+Mfd9k+0pFT423fWC6nMRbTMIopjWc6v09nrWIltUE=")
    (_src "XCursor-Pro-Dark" "tar.gz" "sha256-wJ6rDCLwfOkGpYXVtfwTur8XHyu+WXk7XDhsroik5Os=")
    (_src "XCursor-Pro-Red" "tar.gz" "sha256-YgGJR8l2CfYiIdnFOsz2dg/TjzT7/9CMVoiqZkpOa64=")
  ];
in stdenv.mkDerivation rec {
  pname = "xcursor-pro";
  inherit version;
  inherit srcs;

  sourceRoot = ".";

  installPhase = ''
    install -dm 0755 $out/share/icons
    cp -r XCursor* $out/share/icons/
  '';

  meta = with lib; {
    description = "Modern XCursors.";
    homepage = "https://github.com/ful1e5/XCursor-pro";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = with maintainers; [ njdom24 ];
  };
}
