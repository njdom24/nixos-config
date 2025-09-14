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
            ${pkgs.libnotify}/bin/notify-send "Starting GPU Screen Recorder"
          else
            ${pkgs.libnotify}/bin/notify-send "Select display for replay capture"
          fi

          cmd_base=(
            ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder
            -w portal
            -restore-portal-session yes
            -portal-session-token-filepath "$token_file"
            -a "default_output"
            -q "medium"
            -r 120
            -sc "$(which notify-send)"
            -c mkv
            -o "/home/$USER/Replays"
            -ro "/home/$USER/Recordings"
          )
          
          try_codec() {
            codec="$1"
            echo "Trying codec: $codec"
            ${pkgs.libnotify}/bin/notify-send "Trying codec: $codec"

            # Create a named pipe for logs
            pipe=$(${pkgs.mktemp}/bin/mktemp -u)
            ${pkgs.coreutils}/bin/mkfifo "$pipe"

            # Start gpu-screen-recorder writing to the pipe
            "''${cmd_base[@]}" -k "$codec" >"$pipe" 2>&1 &
            gsr_pid=$!
            # "''$()"

            # Read the output in the main shell
            while IFS= read -r line; do
              if [[ "$line" =~ "update fps:" ]]; then
                continue
              elif [[ "$line" =~ "not supported" ]]; then
                echo "Codec $codec failed, killing process..."
                ${pkgs.libnotify}/bin/notify-send "Codec $codec failed, killing process..."
                kill "$gsr_pid" 2>/dev/null || true
                rm -f "$pipe"
                return 1
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
          }

          for codec in av1 hevc h264; do
            if try_codec "$codec"; then
              # Successfully started with this codec
              break
            fi
          done
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
