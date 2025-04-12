# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }:
let
  # Reapply saved RGB luminance settings by getting/setting the saved value and "poking" the monitor with them
  # Decent settings to load: ddcutil --model="Mi Monitor" setvcp 16 63 18 63 1A 64
  xiaomiFix = pkgs.writeShellScript "xiaomi-brightness-fix" ''
    max_attempts=3
    attempt=1

    # Check VCP 0x16 (Video gain: Red)
    while (( attempt <= max_attempts )); do
        output=$(${pkgs.ddcutil}/bin/ddcutil --model="Mi Monitor" --sleep-multiplier=0.025 getvcp 0x16 2>&1)

        if echo "$output" | grep -q 'current value'; then
            value=$(echo "$output" | ${pkgs.gnused}/bin/sed -nE 's/.*current value = *([0-9]+).*/\1/p')
            if [[ -n "$value" ]]; then
                if (( value < 60 )); then
                    echo "Error: VCP 0x16 (Red gain) is below 60 — value = $value"
                    exit 1
                fi

                echo "Success on attempt $attempt: Current value = $value"
                while ! ${pkgs.ddcutil}/bin/ddcutil setvcp 0x16 "$value" --model="Mi Monitor" --sleep-multiplier=0.025; do
                    sleep 0.1
                done
                exit 0
            fi
        fi

        echo "Attempt $attempt failed: $output"
        ((attempt++))
        sleep 1
    done

    echo "Failed to get VCP value after $max_attempts attempts."
    exit 1
  '';
  hdrWatcher = pkgs.writeShellScript "trigger-hdr" ''
    exec > >(tee "/tmp/somefile.log") 2>&1
    TIME_THRESHOLD=1
    LAST_TIMESTAMP=0

    ${pkgs.systemd}/bin/journalctl -kf | ${pkgs.gnugrep}/bin/grep --line-buffered "HDR SB" | while read -r line; do
        TIMESTAMP=$(echo "$line" | ${pkgs.gawk}/bin/awk '{print $1 " " $2 " " $3}')
        CURRENT_TIMESTAMP=$(${pkgs.coreutils}/bin/date -d "$TIMESTAMP" +%s)

        if [ $LAST_TIMESTAMP -ne 0 ]; then
            TIME_DIFF=$((CURRENT_TIMESTAMP - LAST_TIMESTAMP))
            if [ $TIME_DIFF -ge $TIME_THRESHOLD ]; then
                echo "Time threshold reached. Triggering action..."
                FOUND=0
                for edid in /sys/class/drm/card*/card*/edid; do
                  if [ -f "$edid" ]; then
                    monitor_name=$(${pkgs.coreutils}/bin/cat "$edid" | ${pkgs.edid-decode}/bin/edid-decode | ${pkgs.gawk}/bin/awk -F ': ' '/Display Product Name/ { print $2; exit }')
                    if [ -n "$monitor_name" ]; then
                      echo "$monitor_name"
                      FOUND=1
                      break
                    fi
                  fi
                done
                
                if [ "$FOUND" -eq 0 ]; then
                    echo "Monitor not found. Ignoring."
                fi

                ${xiaomiFix}
            fi
        fi

        LAST_TIMESTAMP=$CURRENT_TIMESTAMP
    done
  '';
in
{
  systemd.services.hdr-watcher = {
    description = "Fix Xiaomi G Pro 27i HDR Brightness";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${hdrWatcher}";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  hardware = {
    # https://github.com/NixOS/nixpkgs/pull/279789#issuecomment-2148560802
    display = {
      outputs."HDMI-A-1".edid = "edid_qm851g.bin"; # Fix 1440p144hz, VRR to 70+ to work around judder (LFC instead)
      outputs."HDMI-A-1".mode = "e";
      outputs."DP-1".edid = "edid_xiaomi.bin"; # Fix MaxCLL, MaxFALL to 1300 nits (measured)
      outputs."DP-1".mode = "e";
      edid.packages = [
        (pkgs.runCommand "custom-edid" {} ''
          mkdir -p $out/lib/firmware/edid
          cp ${./edid_qm851g.bin} $out/lib/firmware/edid/edid_qm851g.bin
          cp ${./edid_xiaomi.bin} $out/lib/firmware/edid/edid_xiaomi.bin
        '')
      ];
    };
  };

  environment.sessionVariables = {
  };
}
