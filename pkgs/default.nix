# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{ pkgs, ...}: {
  plasma-toggle-hdr = pkgs.writeShellScriptBin "plasma-toggle-hdr" ''
    #!/usr/bin/env bash

    json=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j)
    
    mapfile -t enabled < <(jq -r '.outputs[] | select(.connected and .enabled and has("hdr") and .hdr == true) | .name' <<< "$json")
    mapfile -t disabled < <(jq -r '.outputs[] | select(.connected and .enabled and has("hdr") and .hdr == false) | .name' <<< "$json")

    ''$() # Fix syntax highlighting
    if [ ''${#enabled[@]} -eq 0 ]; then
      echo "HDR-disabled displays: ''${disabled[*]}"
      for d in "''${disabled[@]}"; do
        echo "Enabling HDR for '$d'"
        ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$d.wcg.enable output.$d.hdr.enable
      done
    else
      echo "HDR-enabled displays: ''${enabled[*]}"
      for d in "''${enabled[@]}"; do
        echo "Disabling HDR for '$d'"
        ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$d.hdr.disable output.$d.wcg.disable
      done
    fi
  '';
}
