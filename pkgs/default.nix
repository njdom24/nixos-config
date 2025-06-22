# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{ pkgs, ...}: {
  plasma-toggle-hdr = pkgs.writeShellScriptBin "plasma-toggle-hdr" ''
    #!/usr/bin/env bash

    hdr_enabled_outputs=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o | ${pkgs.colorized-logs}/bin/ansi2txt | ${pkgs.gawk}/bin/awk '/^Output:/ {if(hdr) print out; out=$3; hdr=0; next} {l=$0; sub(/^[ \t]+/, "", l); if(l=="HDR: enabled") hdr=1} END {if(hdr) print out}')
    hdr_disabled_outputs=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o | ${pkgs.colorized-logs}/bin/ansi2txt | ${pkgs.gawk}/bin/awk '/^Output:/ {if(hdr) print out; out=$3; hdr=0; next} {l=$0; sub(/^[ \t]+/, "", l); if(l=="HDR: disabled") hdr=1} END {if(hdr) print out}')
    
    if [ -z "$hdr_enabled_outputs" ]; then
      echo "HDR-disabled displays: $hdr_disabled_outputs"
      if [ -n "$hdr_disabled_outputs" ]; then
        for display in $hdr_disabled_outputs; do
          echo "Enabling HDR for '$display'"
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$display.wcg.enable
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$display.hdr.enable
        done
      fi
    else
      echo "HDR-enabled displays: $hdr_enabled_outputs"
      if [ -n "$hdr_enabled_outputs" ]; then
        for display in $hdr_enabled_outputs; do
          echo "Disabling HDR for '$display'"
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$display.hdr.disable
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.$display.wcg.disable
        done
      fi
    fi
  '';
}
