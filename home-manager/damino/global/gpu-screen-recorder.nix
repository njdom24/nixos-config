{ config, pkgs, ... }:

{
  systemd.user.services.gpu-screen-recorder = {
    Unit = {
      Description = "GPU Screen Recorder";
      After = [ "graphical-session.target" ];
      # Stop this service when sunshine starts
      Conflicts = [ "sunshine.service" ];
    };

    Service = {
      ExecStart = let
        gsr-notify = pkgs.writeShellScript "gsr-notify" ''
          path=$1
          type=$2

          if [[ -n "$type" ]]; then
            case "$type" in
              "regular")
                ${pkgs.libnotify}/bin/notify-send "Recording saved" "$path"
                ;;
              "replay")
                ${pkgs.libnotify}/bin/notify-send "Replay saved" "$path"
                ;;
              *)
                echo "Unknown type: $type"
                ;;
            esac
          fi
        '';
        gsr-watcher = pkgs.writeShellScript "gsr-watcher" ''
          if [[ "$XDG_CURRENT_DESKTOP" != "Hyprland" ]]; then
            echo "Currently only supports Hyprland..."
            exit 0
          fi

          # Collect connector name + model for active monitors
          monitors=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.dpmsStatus == 1) | "\(.name):\(.model)"')

          # Generate a unique hash from monitor configuration
          hash=$(${pkgs.coreutils}/bin/printf "%s\n" "$monitors" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

          token_file="/home/$USER/.config/gpu-screen-recorder/restore_token_$hash"
          echo "Using token $token_file"
          
          if [[ -s "$token_file" ]]; then
            echo "Starting GPU Screen Recorder"
          else
            ${pkgs.libnotify}/bin/notify-send "Select display for replay capture"
          fi

          PRIORITY=("av1" "hevc" "h264")
          # Parse available codecs from gpu-screen-recorder --info
          codecs=$(${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder --info | ${pkgs.gawk}/bin/awk '
            $1 == "section=video_codecs" { in_section=1; next }
            /^section=/ { in_section=0 }
            in_section { print $1 }
          ')

          # Pick the best available codec
          best_codec="h264"
          for c in "''${PRIORITY[@]}"; do
            if echo "$codecs" | ${pkgs.gnugrep}/bin/grep -qx "$c"; then
              best_codec="$c"
              break
              "''$()"
            fi
          done

          cmd_base=(
            ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder
            -w portal
            -restore-portal-session yes
            -portal-session-token-filepath "$token_file"
            -a "default_output"
            -q "high"
            -r 120
            -sc "${gsr-notify}"
            -c mkv
            -k "$best_codec"
            -o "/home/$USER/Replays"
            -ro "/home/$USER/Recordings"
          )

          # Create a named pipe for logs
          pipe=$(${pkgs.mktemp}/bin/mktemp -u)
          ${pkgs.coreutils}/bin/mkfifo "$pipe"

          # Start gpu-screen-recorder writing to the pipe
          "''${cmd_base[@]}" >"$pipe" 2>&1 &
          gsr_pid=$!
          # "''$()"

          # Read the output in the main shell
          while IFS= read -r line; do
            if [[ "$line" =~ "update fps:" ]]; then
              continue
            # Detect PipeWire unconnected state
            elif [[ "$line" =~ "new state: \"unconnected\"" ]]; then
              echo "Replay buffer disconnected. Restarting..."
              ${pkgs.libnotify}/bin/notify-send "Replay buffer disconnected. Restarting..."
              kill "$gsr_pid" 2>/dev/null || true
              exit 1
              break
            else
              echo "$line"
            fi
          done <"$pipe"
          rm -f "$pipe"
        ''; in
        "${gsr-watcher}";
      Restart = "on-failure";
      RestartSec = 10;
    };

    #Install = {
      #WantedBy = [ "graphical-session.target" ];
    #};
  };
}
