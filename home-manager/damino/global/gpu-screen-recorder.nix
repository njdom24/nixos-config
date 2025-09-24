{ config, pkgs, ... }: let
  hdr-to-sdr = pkgs.writeShellScriptBin "hdr-to-sdr" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [ $# -ne 1 ]; then
      echo "Usage: $(basename $0) <input_file>"
      exit 1
    fi

    # Handle CTRL+C to exit immediately
    trap 'echo "Interrupted! Exiting..."; exit 1' SIGINT SIGTERM

    input="$1"
    dir=$(dirname "$input")
    filename=$(basename "$input")
    name="''${filename%.*}"
    ext="''${filename##*.}"
    output="$dir/''${name}_SDR.$ext"
    # "''$()"

    # spline chosen over bt.2446a due to being pale
    # Try GPU Vulkan/libplacebo path
    if ${pkgs.coreutils}/bin/nice -n 18 ${pkgs.ffmpeg-full}/bin/ffmpeg -y -init_hw_device vulkan \
      -i "$input" \
      -vf "hwupload,libplacebo=tonemapping=spline:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=limited,hwdownload,format=yuv420p10" \
      -c:v libx265 -crf 22 -preset medium -c:a copy "$output"
    then
      echo "GPU tonemapping succeeded." >&2
    else
      echo "GPU tonemapping failed, falling back to CPU..." >&2
      ${pkgs.coreutils}/bin/nice -n 18 ${pkgs.ffmpeg-full}/bin/ffmpeg -i "$input" \
        -vf "
        zscale=t=linear:npl=100:p=bt2020:m=bt2020nc,format=gbrpf32le, \
        tonemap=tonemap=reinhard:desat=0, \
        zscale=t=bt709:m=bt709:r=tv,format=yuv420p
        " -c:v libx265 -crf 22 -preset medium \
        "$output"
    fi
  '';
in {
  systemd.user.services.gpu-screen-recorder = {
    Unit = {
      Description = "GPU Screen Recorder";
      After = [ "graphical-session.target" ];
      # Stop this service when sunshine starts
      Conflicts = [ "sunshine.service" ];
      Wants = [ "gamepad-watcher.service" ];
    };

    Service = {
      ExecStart = let
        gsr-notify = pkgs.writeShellScript "gsr-notify" ''
          path=$1
          type=$2

          if [[ -n "$type" ]]; then
            case "$type" in
              "regular")
                transfer=$(${pkgs.ffmpeg-full}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
                    -of default=noprint_wrappers=1:nokey=1 "$path")
                if [[ "$transfer" =~ smpte2084|arib-std-b67 ]]; then
                  ${pkgs.libnotify}/bin/notify-send "Recording saved (HDR)" "$path"
                  echo "HDR detected in $file (transfer=$transfer), converting to SDR..."
                  echo "$path" >> /home/$USER/.config/gpu-screen-recorder/hdr-to-sdr.queue
                else
                  ${pkgs.libnotify}/bin/notify-send "Recording saved" "$path"
                fi
                ;;
              "replay")
                transfer=$(${pkgs.ffmpeg-full}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
                    -of default=noprint_wrappers=1:nokey=1 "$path")
                if [[ "$transfer" =~ smpte2084|arib-std-b67 ]]; then
                  ${pkgs.libnotify}/bin/notify-send "Replay saved (HDR)" "$path"
                  echo "HDR detected in $file (transfer=$transfer), converting to SDR..."
                  echo "$path" >> /home/$USER/.config/gpu-screen-recorder/hdr-to-sdr.queue
                else
                  ${pkgs.libnotify}/bin/notify-send "Replay saved" "$path"
                fi
                ;;
              *)
                echo "Unknown type: $type"
                ;;
            esac
          fi
        '';
        gsr-watcher = pkgs.writeShellScript "gsr-watcher" ''
          set -euo pipefail
        
          # Collect active monitors and build hash
          monitors=""
          case "$XDG_CURRENT_DESKTOP" in
            Hyprland)
              monitors=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.dpmsStatus == true) | "\(.name):\(.model)"' | sort)
              ;;
            *)
              # Fallback to xrandr for other desktops or if other tools are missing
              monitors=$(${pkgs.xorg.xrandr}/bin/xrandr --query | ${pkgs.gawk}/bin/awk '/ connected/ {print $1 ":unknown"}' | sort)
              ;;
          esac

          hash=$(${pkgs.coreutils}/bin/printf "%s\n" "$monitors" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

          portal_token="/home/$USER/.config/gpu-screen-recorder/$XDG_CURRENT_DESKTOP/portal/restore_token_$hash"
          kms_token="/home/$USER/.config/gpu-screen-recorder/$XDG_CURRENT_DESKTOP/kmsgrab/restore_token_$hash"
          mkdir -p "$(dirname "$portal_token")" "$(dirname "$kms_token")"
        
          # Pick display
          mode="portal"
          PRIORITY=("av1" "hevc" "h264")
          output=""

          # Detect HDR from ~/.config/hypr/displays.conf
          detect_hdr() {
            case "$XDG_CURRENT_DESKTOP" in
              Hyprland)
                local out="$1"
                local conf="$HOME/.config/hypr/displays.conf"
                [[ -f "$conf" ]] || { echo "sdr"; return; }

                ${pkgs.gawk}/bin/awk -v out="$out" '
                  $1 == "monitorv2" { in_block=1; buf=""; next }
                  in_block && $1 == "}" {
                    in_block=0
                    if (buf ~ "output *= *"out) print buf
                    buf=""
                    next
                  }
                  in_block { buf = buf "\n" $0 }
                ' "$conf" | ${pkgs.gnugrep}/bin/grep -q "cm *= *hdr" && echo "hdr" || echo "sdr"
                ;;
              KDE)
                echo "sdr" # TODO
                ;;
              *)
                echo "sdr"
                ;;
            esac
          }

          hdr_status=$(detect_hdr "$output")

          if [[ "$hdr_status" == "hdr" && "''${FORCE_PORTAL:-0}" != "1" ]]; then
            # "''$()"
            if [[ -s "$kms_token" ]]; then
              output=$(cat "$kms_token")
              if [[ -n "$output" ]]; then
                mode="kmsgrab"
              fi
            else
              selection=$(${pkgs.xdg-desktop-portal-hyprland}/bin/hyprland-share-picker 2>/dev/null || true)
              if [[ "$selection" =~ ^.*/screen:(.+)$ ]]; then
                output="''${BASH_REMATCH[1]}"
                # "''$()"
                echo "$output" >"$kms_token"
                mode="kmsgrab"
              fi
            fi
            if [[ "$mode" == "kmsgrab" ]]; then
              PRIORITY=("av1_hdr" "hevc_hdr" "av1" "hevc" "h264")
            fi
          fi
        
          # Collect available codecs
          codecs=$(${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder --info | ${pkgs.gawk}/bin/awk '
            $1 == "section=video_codecs" { in_section=1; next }
            /^section=/ { in_section=0 }
            in_section { print $1 }
          ')
        
          pick_codec() {
            for c in "''${PRIORITY[@]}"; do
              if echo "$codecs" | ${pkgs.gnugrep}/bin/grep -qx "$c"; then
                # "''$()"
                printf "%s" "$c"
                return 0
              fi
            done
            printf "h264"
          }
        
          best_codec=$(pick_codec)
          # Ensure we don't run kmsgrab unless HDR codec is available
          if [[ "$hdr_status" == "hdr" && "$best_codec" != *hdr* ]]; then
            echo "HDR codec not available for $output (picked $best_codec). Falling back to portal."
            mode="portal"
          fi
        
          # Common args
          cmd_base=(
            ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder
            -a "default_output"
            -q "high"
            -r 300
            -sc "${gsr-notify}"
            -c mkv
            -k "$best_codec"
            -o "/home/$USER/Replays"
            -ro "/home/$USER/Recordings"
          )
        
          if [[ "$mode" == "kmsgrab" && "$hdr_status" == "hdr" ]]; then
            echo "Using kmsgrab for output=$output codec=$best_codec"
            cmd_base+=(-w "$output")
          else
            if [[ "$mode" == "kmsgrab" ]]; then
              echo "Selected display is not HDR; Using portal"
            else
              echo "Using portal capture"
            fi
            cmd_base+=(
              -w portal
              -restore-portal-session yes
              -portal-session-token-filepath "$portal_token"
              -fm content
            )
          fi
        
          # Create named pipe for communication
          pipe=$(${pkgs.mktemp}/bin/mktemp -u)
          ${pkgs.coreutils}/bin/mkfifo "$pipe"
        
          "''${cmd_base[@]}" >"$pipe" 2>&1 &
          gsr_pid=$!
          # "''$()"
        
          # cleanup helpers
          stop_gsr() {
            if [[ -n "''${gsr_pid:-}" ]]; then
              # "''$()"
              kill "$gsr_pid" 2>/dev/null || true
              wait "$gsr_pid" 2>/dev/null || true
              gsr_pid=""
            fi
            [[ -n "${pipe:-}" ]] && rm -f "$pipe"
          }

          # Background HDR tonemapping
          (
            CONFIG_DIR="$HOME/.config/gpu-screen-recorder"
            QUEUE="$CONFIG_DIR/hdr-to-sdr.queue"
            mkdir -p "$CONFIG_DIR"
            touch "$QUEUE"
          
            while true; do
              if [[ -s "$QUEUE" ]]; then
                filepath=$(head -n1 "$QUEUE")
                [[ -z "$filepath" ]] && {
                  # Drop empty line safely
                  tail -n +2 "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
                  continue
                }
          
                echo "Tonemapping $filepath"
                #${pkgs.libnotify}/bin/notify-send "Tonemapping $filepath"
          
                ${hdr-to-sdr}/bin/hdr-to-sdr "$filepath"
                status=$?
          
                if [[ $status -eq 0 ]]; then
                  ${pkgs.libnotify}/bin/notify-send "Tonemapping finished" "$(basename "$filepath")"
                else
                  ${pkgs.libnotify}/bin/notify-send "Tonemapping failed" "$(basename "$filepath")"
                fi
          
                # Remove job from the queue
                tail -n +2 "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
              else
                # Sleep until something in the directory changes
                ${pkgs.inotify-tools}/bin/inotifywait -q -e modify "$CONFIG_DIR" >/dev/null 2>&1
              fi
            done
          ) &
        
          trap 'stop_gsr; exit 0' TERM INT
        
          # On reload: re-evaluate HDR (only relevant if kmsgrab was chosen).
          # If HDR status changed, restart the whole service so systemd gives it a clean slate.
          trap '
            if [[ "''${FORCE_PORTAL:-0}" != "1" ]]; then
              # "''$()"
              new_hdr=$(detect_hdr "$output")
              if [[ "$new_hdr" != "$hdr_status" ]]; then
                echo "HDR status changed ($hdr_status -> $new_hdr)"
                ${pkgs.libnotify}/bin/notify-send "HDR status changed ($hdr_status -> $new_hdr), restarting service..."
                ${pkgs.systemd}/bin/systemctl --user restart gpu-screen-recorder
              else
                echo "Reload received: HDR unchanged ($hdr_status)."
              fi
            fi
          ' HUP
        
          # Read output and handle noteworthy output
          while IFS= read -r line; do
            if [[ "$line" =~ "update fps:" ]]; then
              # spammy status line — ignore
              continue
            elif [[ "$line" =~ "new state: \"unconnected\"" ]]; then
              echo "Replay buffer disconnected. Restarting..."
              ${pkgs.libnotify}/bin/notify-send "Replay buffer disconnected. Restarting..."
              # kill + exit so systemd restarts this watcher (Restart=.. will take care of it)
              kill "$gsr_pid" 2>/dev/null || true
              exit 1
            elif [[ "$line" =~ "gsr error: gsr_capture_kms_capture: failed to get kms" ]]; then
              # Saving HDR replays causes a crash...
              kill "$gsr_pid" 2>/dev/null || true
              exit 1
            else
              echo "$line"
            fi
          done <"$pipe"
        
          rm -f "$pipe"
        '' ;
         in
        "${gsr-watcher}";
      Restart = "on-failure";
      RestartSec = 10;
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      #Environment = "FORCE_PORTAL=1"; # TODO: Remove if saving HDR replays stops crashing
    };

    #Install = {
      #WantedBy = [ "graphical-session.target" ];
    #};
  };

  home.packages = with pkgs; [
    hdr-to-sdr
  ];
}
