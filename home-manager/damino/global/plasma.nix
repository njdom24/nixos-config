
# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  hostName,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.stable-packages
      outputs.overlays.unstable-packages
      outputs.overlays.legacy-packages
    ];
  };

  home = {
    file =
    let sunshine-login = pkgs.writeShellScript "sunshine-login" ''
      if [ -f /tmp/sunshine_login ] && [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
        if ${pkgs.gawk}/bin/awk '
        /CLIENT CONNECTED/ {e=1}
        e && /CLIENT DISCONNECTED/ {cancel=1}
        END { if (e && !cancel) exit 0; else exit 1 }
        ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/sunshine_login); then
          # Disable RGB
          ${pkgs.openrgb}/bin/openrgb --mode static --color 000000

          # Assume dummy display used for headless
          DUMMY="HDMI-A-1"
          
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".enable
          
          output=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o)
          
          # Extract the names of the connected displays
          displays=$(echo "$output" | ${pkgs.gawk}/bin/awk '/Output:/ { print $3 }')
          echo "Displays found: $displays"

          # Check if the dummy display is present
          echo "$displays" | grep -qx "$DUMMY"
          if [ $? -ne 0 ]; then
            echo "$DUMMY is not connected."
          fi
          
          # Loop through each display and disable all except DUMMY
          while read -r display; do
            if [[ "$display" != "$DUMMY" ]]; then
              echo "Disabling display: $display"
              ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$display".disable
            fi
          done <<< "$displays"

          systemctl --user start sunshine
        else
          # Get all connected and enabled outputs
          outputs=($(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j | ${pkgs.jq}/bin/jq -r '
            .outputs[]
            | select(.connected == true and .enabled == true)
            | .name
          '))
          
          len=''${#outputs[@]}
          first=''${outputs[0]:-}
          
          if [[ $len -eq 1 && "$first" == "$DUMMY" ]]; then
            echo "Only dummy is enabled and connected. Restoring..."
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.enable
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-2.enable
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.enable
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".disable
            ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.primary
          else
            echo "Dummy is not the only enabled connected output"
          fi
        fi
      fi
    '';
    in {
      ".face.icon".source = ./.face.icon;
      ".config/autostart/sunshine-remote.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Exec=${sunshine-login}
          Hidden=false
          NoDisplay=true
          X-GNOME-Autostart-enabled=true
          Name=My Script
          Comment=Checks for remote login and starts sunshine
        '';
    };

    packages = with pkgs; [
    ];
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
