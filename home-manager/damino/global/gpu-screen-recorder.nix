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
    max_retries=5
    attempt=1
    success=false

    # Retries due to occasional spurious failures with Vulkan encode
    # Try full GPU Vulkan/libplacebo path
    while (( attempt <= max_retries )); do
      echo "Attempt $attempt/$max_retries: GPU tonemapping / GPU encode..." >&2
      if ${pkgs.coreutils}/bin/nice -n 18 ${pkgs.ffmpeg-full}/bin/ffmpeg -y \
        -init_hw_device vulkan=vkdev:0 -filter_hw_device vkdev \
        -i "$input" \
        -vf "libplacebo=tonemapping=gamma:tonemapping_param=2.2:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=full,format=p010,hwupload" \
        -c:v hevc_vulkan -b:v 20M -preset p5 -c:a copy "$output"
      then
        echo "GPU tonemapping / GPU encode succeeded." >&2
        success=true
        break
      else
        echo "Attempt $attempt failed, retrying..." >&2
        ((attempt++))
        sleep 3 # small delay before retry
      fi
    done
    
    if ! $success; then
      echo "GPU tonemapping / GPU encode failed after $max_retries attempts." >&2

      if ${pkgs.coreutils}/bin/nice -n 18 ${pkgs.ffmpeg-full}/bin/ffmpeg -y -init_hw_device vulkan \
        -i "$input" \
        -vf "hwupload,libplacebo=tonemapping=gamma:tonemapping_param=2.2:colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=full,hwdownload,format=yuv420p10" \
        -c:v libx265 -crf 22 -preset medium -c:a copy "$output"
      then
        echo "GPU tonemapping / CPU encode succeeded." >&2
      else
        echo "GPU acceleration failed, falling back to CPU..." >&2
        ${pkgs.coreutils}/bin/nice -n 18 ${pkgs.ffmpeg-full}/bin/ffmpeg -i "$input" \
        -vf "zscale=transfer=smpte2084:primaries=bt2020:matrix=bt2020nc:t=linear:npl=100,tonemap=hable:desat=0,zscale=transfer=bt709:primaries=bt709:matrix=bt709,format=yuv420p" \
        -c:v libx265 -crf 22 -preset medium \
        "$output"
      fi
    fi
  '';
  discord-compress = pkgs.writeShellScriptBin "discord-compress" ''
    # Discord-style HEVC compression (~10 MB target)
    input="$1"
    output="$input"_compressed.mkv
    target_size_mb="''${2:-10}" # Optional arg, default 10 MB
    
    if [[ -z "$input" ]]; then
      echo "Usage: $0 <input-file> [target_MB]"
      exit 1
    fi

    # --- Clean exit on Ctrl-C
    cleanup() {
        echo "Exiting..."
        # Kill any running ffmpeg child processes
        ${pkgs.procps}/bin/pkill -P $$ 2>/dev/null || true
        exit 1
    }
    trap cleanup SIGINT

    # --- Get video duration in seconds
    duration=$(${pkgs.ffmpeg-full}/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$input")
    duration=''${duration%.*}
    duration=$((duration + 1))
    
    # --- Audio bitrate in kbps
    audio_bitrate=128
    
    # --- Calculate target video bitrate in kbps
    target_bitrate=$(( (target_size_mb * 8192 - audio_bitrate * duration) / duration ))
    echo "Target video bitrate: ''${target_bitrate} kbps (~''${target_size_mb} MB total)"
    
    # --- Get resolution
    read -r width height <<< "$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=p=0 "$input")"
    
    # --- Max Discord resolution
    max_width=1920
    max_height=1080
    
    # --- First pass (no output)
    ${pkgs.ffmpeg-full}/bin/ffmpeg -y -i "$input" \
        -vf "scale='min(1920\,iw)':'min(1080\,ih)':force_original_aspect_ratio=decrease" \
        -c:v libx265 -b:v ''${target_bitrate}k -preset medium -x265-params pass=1 \
        -an -f null /dev/null
    
    # --- Second pass
    ${pkgs.ffmpeg-full}/bin/ffmpeg -y -i "$input" \
        -vf "scale='min(1920\,iw)':'min(1080\,ih)':force_original_aspect_ratio=decrease" \
        -c:v libx265 -b:v ''${target_bitrate}k -preset medium -x265-params pass=2 \
        -c:a aac -b:a 128k \
        -movflags +faststart \
        "$output"

    # "''$()
    echo "Done: $output"
  '';
in {
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
                transfer=$(${pkgs.ffmpeg-full}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
                    -of default=noprint_wrappers=1:nokey=1 "$path")
                if [[ "$transfer" =~ smpte2084|arib-std-b67 ]]; then
                  ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Recording saved (HDR)" "$path"
                else
                  ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Recording saved" "$path"
                fi
                ;;
              "replay")
                transfer=$(${pkgs.ffmpeg-full}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
                    -of default=noprint_wrappers=1:nokey=1 "$path")
                if [[ "$transfer" =~ smpte2084|arib-std-b67 ]]; then
                  ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Replay saved (HDR)" "$path"
                else
                  ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Replay saved" "$path"
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
              monitors=$(${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[] | select(.disabled == false) | "\(.name):\(.model)"' | ${pkgs.coreutils}/bin/sort)
              ;;
            sway)
              monitors=$(${pkgs.sway}/bin/swaymsg -t get_outputs -r | ${pkgs.jq}/bin/jq -r '
                .[]
                | select(.active == true)
                | "\(.name):\(.make // "unknown") \(.model // "")"
              ' | ${pkgs.coreutils}/bin/sort)
              
              monitors=$(echo "$monitors" | ${pkgs.gnugrep}/bin/grep -v '^HEADLESS')
              ;;
            jay)
              monitors=$(jay randr | ${pkgs.gawk}/bin/awk '
                /^      [A-Z]+-[0-9]+:$/ {
                  if (active && manufacturer != "") print connector ":" manufacturer " " product
                  connector = substr($0, 7, length($0) - 7)
                  active = 0
                  manufacturer = ""
                  product = ""
                }
                /^        product:/ {
                  sub(/^        product: /, "")
                  product = $0
                }
                /^        manufacturer:/ {
                  sub(/^        manufacturer: /, "")
                  manufacturer = $0
                }
                /^        logical size:/ {
                  active = 1
                }
                END {
                  if (active && manufacturer != "") print connector ":" manufacturer " " product
                }
              ' | sort)
              ;;
            KDE)
              monitors=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j | ${pkgs.jq}/bin/jq -r '.outputs[] | select(.connected == true and .priority > 0) | "\(.name):\(.pos.x)x\(.pos.y)"' | ${pkgs.coreutils}/bin/sort)
              ;;
            *)
              # Fallback to xrandr for other desktops or if other tools are missing
              monitors=$(${pkgs.xrandr}/bin/xrandr --query 2>/dev/null | ${pkgs.gawk}/bin/awk '/ connected/ {print $1 ":unknown"}' | ${pkgs.coreutils}/bin/sort)
              ;;
          esac

          hash=$(${pkgs.coreutils}/bin/printf "%s\n" "$monitors" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

          portal_token="/home/$USER/.config/gpu-screen-recorder/$XDG_CURRENT_DESKTOP/portal/restore_token_$hash"
          kms_token="/home/$USER/.config/gpu-screen-recorder/$XDG_CURRENT_DESKTOP/kmsgrab/restore_token_$hash"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$portal_token")" "$(${pkgs.coreutils}/bin/dirname "$kms_token")"
        
          # Pick display
          mode="portal"
          hdr_status="sdr"
          PRIORITY=("av1" "hevc" "h264")
          output=""
          
          detect_hdr() {
            local out="$1"
            case "$XDG_CURRENT_DESKTOP" in
              Hyprland)
                current_mode="$(${pkgs.hyprland}/bin/hyprctl monitors -j \
                  | ${pkgs.jq}/bin/jq -r --arg monitor "$out" \
                    '.[] | select(.name == $monitor) | .colorManagementPreset')"

                if [[ "$current_mode" == "hdr" ]]; then
                  echo "hdr"
                else
                  echo "sdr"
                fi
                ;;
              sway)
                is_hdr="$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$out\") | .hdr")"
                [[ "$is_hdr" == "true" ]] && echo "hdr" || echo "sdr"
                ;;
              jay)
                if jay randr | ${pkgs.gnugrep}/bin/grep -q 'pq (current)'; then
                  echo "hdr"
                else
                  echo "sdr"
                fi
                ;;
              KDE)
                echo "sdr" # TODO
                ;;
              *)
                echo "sdr"
                ;;
            esac
          }

          if [[ "''${FORCE_PORTAL:-0}" == "1" ]]; then
            # "''$()"
            mode="portal"
          else
            # Default to kmsgrab to not block direct scanout
            mode="kmsgrab"
          fi

          if [[ "$mode" == "kmsgrab" ]]; then
            if [[ -s "$kms_token" ]]; then
              output=$(${pkgs.coreutils}/bin/cat "$kms_token")
            else
              monitor_count=$(printf '%s\n' "$monitors" | ${pkgs.coreutils}/bin/wc -l)
              echo "Monitor count: $monitor_count"
              if [ "$monitor_count" -eq 1 ]; then
                # "''$()"
                output=''${monitors%%:*}
                echo "Using only output: $output"
              else
                selection=$(${pkgs.xdg-desktop-portal-hyprland}/bin/hyprland-share-picker 2>/dev/null || true)
                if [[ "$selection" =~ ^.*/screen:(.+)$ ]]; then
                  output="''${BASH_REMATCH[1]}"
                  # "''$()"
                  echo "$output" > "$kms_token"
                fi
              fi
            fi

            hdr_status=$(detect_hdr "$output")
          fi

          if [[ "$mode" == "kmsgrab" && "$hdr_status" == "hdr" ]]; then
            PRIORITY=("av1_hdr" "hevc_hdr" "av1" "hevc" "h264")
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
        
          if [[ "$mode" == "kmsgrab" ]]; then
            echo "Using kmsgrab for output=$output codec=$best_codec"
            cmd_base+=(-w "$output")
          else
            echo "Using portal capture codec=$best_codec"
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
        
          trap 'stop_gsr; exit 0' TERM INT
        
          # On reload: re-evaluate HDR (only relevant if kmsgrab was chosen).
          # If HDR status changed, restart the whole service so systemd gives it a clean slate.
          trap '
            if [[ "''${FORCE_PORTAL:-0}" != "1" ]]; then
              # "''$()"
              new_hdr=$(detect_hdr "$output")
              if [[ "$new_hdr" != "$hdr_status" ]]; then
                echo "HDR status changed ($hdr_status -> $new_hdr)"
                ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "HDR status changed ($hdr_status -> $new_hdr)" "Restarting service..."
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
              ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Replay buffer disconnected. Restarting..."
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
    discord-compress
  ];
}
