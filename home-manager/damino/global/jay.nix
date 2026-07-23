{ inputs, lib, config, pkgs, ... }: {
  imports = [
  ];
  xdg.portal = {
    configPackages = [ pkgs.jay ];
    config.jay = {
      default = [
        "jay"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "jay" ];
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "jay" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  home =
    let set-bitdepth = pkgs.writeShellScript "set-bitdepth" ''
    usage() {
      echo "Usage: $0 <8|10> [DISPLAY...]"
      exit 1
    }

    [[ $# -ge 1 ]] || usage

    DEPTH="$1"
    shift

    case "$DEPTH" in
      8)
        preferred=(
          xrgb8888
          xbgr8888
          argb8888
          abgr8888
        )
        ;;
      10)
        preferred=(
          xrgb2101010
          xbgr2101010
          argb2101010
          abgr2101010
        )
        ;;
      *)
        usage
        ;;
    esac

    OUTPUT="$(${pkgs.jay}/bin/jay randr show --formats)"

    # If no displays specified, find all enabled ones.
    if [[ $# -eq 0 ]]; then
      mapfile -t displays < <(
        awk '
          /^[[:space:]]+[A-Z0-9-]+:$/ {
            name=$1
            sub(/:$/, "", name)
            enabled=0
          }
          /^[[:space:]]+mode:/ { enabled=1 }
          /^[[:space:]]+[A-Z0-9-]+:$/ && NR!=1 {
            if (prev != "" && prev_enabled)
              print prev
            prev=name
            prev_enabled=enabled
            next
          }
          {
            if ($1=="mode:")
              prev_enabled=1
          }
          END {
            if (prev != "" && prev_enabled)
              print prev
          }
        ' <<<"$OUTPUT"
      )
    else
      displays=("$@")
    fi

    for display in "''${displays[@]}"; do
      format=""

      block="$(${pkgs.gawk}/bin/awk -v d="$display" '
        $1 == d ":" {found=1; next}
        found && /^[[:space:]]+[A-Z0-9-]+:$/ {exit}
        found {print}
      ' <<<"$OUTPUT")"

      for candidate in "''${preferred[@]}"; do
        if ${pkgs.gnugrep}/bin/grep -qx "[[:space:]]*$candidate" <<<"$block"; then
          format="$candidate"
          break
        fi
      done

      if [[ -z "$format" ]]; then
        echo "No suitable $DEPTH bit format found for $display" >&2
        continue
      fi

      echo "$display -> $format"
      ${pkgs.jay}/bin/jay randr output "$display" format set "$format"
    done
    ''; in
    let display-refresh = pkgs.writeShellScript "display-refresh" ''
    OUTPUT="$(${pkgs.jay}/bin/jay randr show --modes)"
    # If no displays specified, find all enabled ones.
    if [[ $# -eq 0 ]]; then
      mapfile -t displays < <(
        ${pkgs.gawk}/bin/awk '
        /^[[:space:]]+[A-Z0-9-]+:$/ {
          if (display && enabled)
            print display

          display=$1
          sub(/:$/, "", display)
          enabled=0
          next
        }

        /^[[:space:]]+mode:/ {
          enabled=1
        }

        END {
          if (display && enabled)
            print display
        }
        ' <<<"$OUTPUT"
      )
    else
      displays=("$@")
    fi

    for display in "''${displays[@]}"; do
      current=""
      modes=()

      while IFS= read -r line; do
        if [[ $line == CURRENT=* ]]; then
          current="''${line#CURRENT=}"
        else
          modes+=("$line")
        fi
      done < <(
        ${pkgs.gawk}/bin/awk -v display="$display" '
        BEGIN {
          in_display = 0
        }

        /^[[:space:]]+[A-Z0-9-]+:$/ {
          name = $1
          sub(/:$/, "", name)
          in_display = (name == display)
          next
        }

        in_display && /^[[:space:]]+[0-9]+ x [0-9]+ @/ {
          mode = $1 "x" $3 "@" $5
          print mode

          if ($6 == "(current)")
            print "CURRENT=" mode
        }
        ' <<<"$OUTPUT"
      )

      if [[ -z "$current" ]]; then
        echo "  Could not determine current mode."
        continue
      fi

      resolution="''${current%@*}"

      alternate=""
      for mode in "''${modes[@]}"; do
        if [[ "$mode" == "$resolution@"* && "$mode" != "$current" ]]; then
          alternate="$mode"
          break
        fi
      done

      if [[ -z "$alternate" ]]; then
        echo "  No alternate refresh found."
        continue
      fi

      echo "  $current -> $alternate -> $current"

      IFS='x@' read -r aw ah ar <<<"$alternate"
      IFS='x@' read -r cw ch cr <<<"$current"

      ${pkgs.jay}/bin/jay randr output "$display" mode "$aw" "$ah" "$ar"
      sleep 1
      ${pkgs.jay}/bin/jay randr output "$display" mode "$cw" "$ch" "$cr"
    done
    ''; in
    let screenshot = pkgs.writeShellScript "screenshot" ''
      mode="$1"
      SCREENSHOT_DIR="$XDG_RUNTIME_DIR/screenshots"
      mkdir -p "$SCREENSHOT_DIR"
      timestamp=$(date +%s)
      tmpfile="$SCREENSHOT_DIR/$timestamp.png"

      cleanup() {
        rm -f "$tmpfile"
      }
      trap cleanup EXIT

      # Clear out old screenshot
      rm -f "$SCREENSHOT_DIR/"*
      ${pkgs.wl-clipboard-rs}/bin/wl-copy ""

      case "$mode" in
        focused)
          monitor=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.focused==true).name")
          ${pkgs.grim}/bin/grim -o "$monitor" "$tmpfile"
          ;;
        select|selector)
          geom=$(${pkgs.slurp}/bin/slurp)
          ${pkgs.grim}/bin/grim -g "$geom" "$tmpfile"
          ;;
        *)
          echo "Usage: $0 {focused|select}" >&2
          exit 1
          ;;
      esac

      if [[ -s "$tmpfile" ]]; then
        # Compression can take a while. Put current image in clipboard for immediate pasting
        ${pkgs.wl-clipboard-rs}/bin/wl-copy --type text/uri-list <<< "file://$tmpfile"
        ${pkgs.libnotify}/bin/notify-send -a "Screenshot" -i "$tmpfile" "Screenshot taken"

        # Compress to WebP for pasting in chat apps
        newfile="$SCREENSHOT_DIR/$timestamp.webp"
        ${pkgs.imagemagick}/bin/magick "$tmpfile" \
          -define webp:lossless=true \
          "$newfile"

        ${pkgs.wl-clipboard-rs}/bin/wl-copy --type text/uri-list <<< "file://$newfile"
        #${pkgs.libnotify}/bin/notify-send -a "Screenshot" -i "$newfile" "Screenshot converted"
      fi
    ''; in {
    packages = with pkgs; [
      (pkgs.writeShellScriptBin "jay-toggle-hdr" ''
        primary_display="$(${pkgs.xrandr}/bin/xrandr 2>/dev/null | ${pkgs.gawk}/bin/awk '/ connected/&&!f{f=$1}/ connected primary/{print $1;found=1;exit}END{if(!found)print f}')"

        read current_eotf current_w current_h current_hz < <(${pkgs.jay}/bin/jay randr | awk "
          /^      $primary_display:/{found=1}
          found && in_eotf && /\(current\)/{eotf=\$1}
          found && /eotfs:/{in_eotf=1}
          found && /^        mode:/{w=\$2; h=\$4; sub(/@/,\"\",h); hz=\$6}
          found && /^      [A-Z]/{if (!/^      $primary_display:/) exit}
          END{print eotf, w, h, hz}
        ")

        set_format() {
          local candidates=("$@")
          for fmt in "''${candidates[@]}"; do
            if ${pkgs.jay}/bin/jay randr output "$primary_display" format set "$fmt" 2>/dev/null; then
              echo "Format set to $fmt"
              return 0
            fi
          done
          echo "Failed to set any format" >&2
          return 1
        }

        desired="''${1,,}"  # lowercase the argument

        case "$desired" in
          on|off) ;;
          "")
            # No argument: toggle
            if [ "$current_eotf" = "pq" ]; then desired="off"; else desired="on"; fi
            ;;
          *)
            echo "Usage: $0 [on|off]" >&2
            exit 1
            ;;
        esac

        if [ "$desired" = "off" ]; then
          if [ "$current_eotf" = "pq" ]; then
            ${pkgs.jay}/bin/jay randr output "$primary_display" colors set default default
            ${display-refresh} "$primary_display"
          fi
        else
          if [ "$current_eotf" != "pq" ]; then
            ${pkgs.jay}/bin/jay randr output "$primary_display" colors set bt2020 pq
            ${set-bitdepth} 10
            ${display-refresh} "$primary_display"
          fi
        fi
      '')
    ];

    file.".config/jay/config.toml" =
      let satellite-loop = pkgs.writeShellScript "satellite-loop" ''
      while true; do
        (sleep 5 && ${pkgs.xrandr}/bin/xrandr --output DP-1 --primary) &
        ${pkgs.xwayland-satellite}/bin/xwayland-satellite
        sleep 1
        status=$?
        echo "xwayland-satellite exited with status $status, restarting in 1 second..." >&2
        sleep 1
      done
    ''; in {
      text = ''
        render-device.name = "dedicated"
        auto-reload = true
        device-config-filter = "new"
        window-management-key = "Super_L"
        focus-follows-mouse = true
        workspace-display-order = "sorted"
        fallback-output-mode = "cursor"
        cursor-size = 25
        show-bar = false
        show-titles = true
        idle = { minutes = 0 }
        gfx-api = "Vulkan"
        vrr = { mode = "variant1", cursor-hz = 90 }

        keymap = """
            xkb_keymap {
                xkb_keycodes { include "evdev+aliases(qwerty)" };
                xkb_types    { include "complete"              };
                xkb_compat   { include "complete"              };
                xkb_symbols  { include "pc+us+inet(evdev)"     };
            };
            """

        # ---------------------------------------------------------------------------
        # Keyboard repeat rate
        # ---------------------------------------------------------------------------
        repeat-rate = { rate = 25, delay = 300 }

        # ---------------------------------------------------------------------------
        # Startup applications
        # ---------------------------------------------------------------------------
        on-graphics-initialized = [
            { type = "exec", exec = ["kanshi"] },
            { type = "exec", exec = ["wlr-hdr-cal"] },
            { type = "exec", exec = ["${satellite-loop}"] },
            { type = "exec", exec = ["noctalia"] },
            { type = "exec", exec = ["firefox"] },
            { type = "exec", exec = ["discord"] },
            { type = "exec", exec = ["sh", "-c", "systemctl --user restart xdg-desktop-portal"] },
            { type = "exec", exec = ["sh", "-c", "sleep 5 && gtk-launch steam.desktop"] },
            { type = "exec", exec = ["jay", "randr", "output", "DP-1", "mode", "3840", "2160", "160"] },
            # Clipboard persistence
            { type = "exec", exec = [
                "${pkgs.wl-clip-persist}/bin/wl-clip-persist", "--clipboard", "regular",
                "--selection-size-limit", "209715200",
                "--reconnect-tries", "1",
                "--all-mime-type-regex", "(?i)^(?!image/x-inkscape-svg).+",
            ] },
            #{ type = "exec", exec = ["jay", "input", "seat", "default", "set-cursor-size", "25"] },
            { type = "exec", exec = ["sh", "-c", "jay randr card $(readlink -f $XDG_RUNTIME_DIR/dri/dgpu0) primary"] },
            { type = "exec", exec = ["sh", "-c", "jay randr card $(readlink -f $XDG_RUNTIME_DIR/dri/dgpu0) plane-color-pipelines enable"] },
            # GPU screen recorder replay buffer (with delay for display init)
            { type = "exec", exec = ["sh", "-c", "sleep 2 && systemctl --user stop gpu-screen-recorder"] },
        ]

        [[drm-devices]]
        name = "dedicated"
        match.devnode = "/run/user/1000/dri/dgpu0"
        #match = { pci-vendor = 0x1002, pci-model = 0x7550 }
        plane-color-pipelines = true

        [transactions]
        timeout.millis = 200

        [color-management]
        enabled = true

        [env]
        SSH_AUTH_SOCK="/run/user/1000/gcr/ssh"
        SSH_ASKPASS="/run/current-system/sw/libexec/seahorse/ssh-askpass"
        DISPLAY = ":0"
        XCURSOR_THEME = "XCursor-Pro-Dark"
        XCURSOR_SIZE = "25"
        QT_QPA_PLATFORM = "wayland;xcb"
        GDK_BACKEND = "wayland,x11"
        CLUTTER_BACKEND = "wayland"
        QT_QPA_PLATFORMTHEME = "qt6ct"
        MOZ_DBUS_REMOTE = "1"
        NIXOS_OZONE_WL = "1"
        XDG_MENU_PREFIX = "plasma-"

        [xwayland]
        enabled = false
        scaling-mode = "default"

        # Map a drawing tablet to the left monitor
        #[[inputs]]
        #match.name = "Wacom Intuos Pro M Pen"
        #output.name = "primary"

        [[inputs]]
        match.name = "Sony Interactive Entertainment Wireless Controller Touchpad"
        detached = true

        [[inputs]]
        match.name = "DualSense Wireless Controller Touchpad"
        detached = true

        [[clients]]
        name = "give-all-permissions"
        capabilities = ["all"]

        [[windows]]
        match.app-id = "Discord"
        action = { type = "move-to-workspace", name = "2" }

        [[windows]]
        match.app-id = "steam"
        action = { type = "move-to-workspace", name = "4" }

        # Suppress focus stealing for Chromium screen-Share windows
        [[windows]]
        match.title-regex = 'is sharing (your screen|a window)\.$'
        match.client.comm = "chromium"
        initial-tile-state = "floating"
        auto-focus = false

        [theme]
        font = "Input Mono 8"
        title-font = "Input Mono 0"
        bar-font = "Input Mono 8"

        title-height = 0
        bar-height = 28
        bar-separator-width = 0
        separator-color = "#00000000"

        border-width = 2
        border-color = "#00000000"
        #focused-border-color = "#${config.colorScheme.palette.base05}"
        focused-border-color = "#${config.colorScheme.palette.base04}"
        #focused-title-bg-color = "#00000000"
        unfocused-title-bg-color = "#00000000"
        show-window-icons = false
        container-borders = "full"
        #container-borders = "separators"

        [workspaces."1"]
        initial-output.name = "primary"

        [workspaces."2"]
        initial-output.name = "secondary"

        [workspaces."4"]
        initial-output.name = "primary"

        # ---------------------------------------------------------------------------
        # Input devices
        # ---------------------------------------------------------------------------
        [[inputs]]
        match.is-pointer = true
        accel-profile = "Flat"

        [[inputs]]
        match.is-touchpad = true
        tap-enabled = true
        natural-scroll = true

        [shortcuts]
        "alt-shift-r"            = { type = "reload-config-toml" }
        # ── Terminal ────────────────────────────────────────────────────────────────
        "logo-Return"            = { type = "exec", exec = "alacritty" }

        # ── Close window ────────────────────────────────────────────────────────────
        "logo-shift-q"           = "close"

        # ── Noctalia panels ─────────────────────────────────────────────────────────
        "logo-d"                 = { type = "exec", exec = ["noctalia", "msg", "panel-toggle", "launcher"] }
        "logo-shift-e"           = { type = "exec", exec = ["noctalia", "msg", "panel-toggle", "session"] }
        "ctrl-grave"             = { type = "exec", exec = ["noctalia", "msg", "panel-toggle", "control-center", "notifications"] }
        "ctrl-space"             = { type = "exec", exec = ["noctalia", "msg", "notification-clear-active"] }

        # ── Focus movement ──────────────────────────────────────────────────────────
        "logo-Left"              = [ "focus-left",  "warp-mouse-to-focus" ]
        "logo-Right"             = [ "focus-right", "warp-mouse-to-focus" ]
        "logo-Up"                = [ "focus-up",    "warp-mouse-to-focus" ]
        "logo-Down"              = [ "focus-down",  "warp-mouse-to-focus" ]

        # ── Window movement ─────────────────────────────────────────────────────────
        "logo-shift-Left"        = "move-left"
        "logo-shift-Right"       = "move-right"
        "logo-shift-Up"          = "move-up"
        "logo-shift-Down"        = "move-down"

        # ── Layout ──────────────────────────────────────────────────────────────────
        "logo-h"                 = "split-horizontal"
        "logo-v"                 = "split-vertical"
        "logo-f"                 = "toggle-fullscreen"
        "logo-shift-space"       = "toggle-floating"
        "logo-space"             = "focus-mode-toggle"
        "logo-a"                 = "focus-parent"
        "logo-t"                 = "toggle-split"
        "logo-m"                 = "toggle-mono"

        # ── Workspaces ──────────────────────────────────────────────────────────────
        # [ "focus-left", "warp-mouse-to-focus" ]
        "logo-1"                 = [ { type = "show-workspace", name = "1", output.name = "primary", move-to-output = true }, "warp-mouse-to-focus" ]
        "logo-2"                 = [ { type = "show-workspace", name = "2", output.name = "secondary", move-to-output = true }, "warp-mouse-to-focus" ]
        "logo-3"                 = [ { type = "show-workspace", name = "3" },  "warp-mouse-to-focus" ]
        "logo-4"                 = [ { type = "show-workspace", name = "4", output.name = "primary", move-to-output = true }, "warp-mouse-to-focus" ]
        "logo-5"                 = [ { type = "show-workspace", name = "5" },  "warp-mouse-to-focus" ]
        "logo-6"                 = [ { type = "show-workspace", name = "6" },  "warp-mouse-to-focus" ]
        "logo-7"                 = [ { type = "show-workspace", name = "7" },  "warp-mouse-to-focus" ]
        "logo-8"                 = [ { type = "show-workspace", name = "8" },  "warp-mouse-to-focus" ]
        "logo-9"                 = [ { type = "show-workspace", name = "9" },  "warp-mouse-to-focus" ]
        "logo-0"                 = [ { type = "show-workspace", name = "10" }, "warp-mouse-to-focus" ]

        "logo-shift-1"           = { type = "move-to-workspace", name = "1" }
        "logo-shift-2"           = { type = "move-to-workspace", name = "2" }
        "logo-shift-3"           = { type = "move-to-workspace", name = "3" }
        "logo-shift-4"           = { type = "move-to-workspace", name = "4" }
        "logo-shift-5"           = { type = "move-to-workspace", name = "5" }
        "logo-shift-6"           = { type = "move-to-workspace", name = "6" }
        "logo-shift-7"           = { type = "move-to-workspace", name = "7" }
        "logo-shift-8"           = { type = "move-to-workspace", name = "8" }
        "logo-shift-9"           = { type = "move-to-workspace", name = "9" }
        "logo-shift-0"           = { type = "move-to-workspace", name = "10" }

        # ── VT switching ────────────────────────────────────────────────────────────
        "ctrl-alt-F1"            = { type = "switch-to-vt", num = 1 }
        "ctrl-alt-F2"            = { type = "switch-to-vt", num = 2 }
        "ctrl-alt-F3"            = { type = "switch-to-vt", num = 3 }
        "ctrl-alt-F4"            = { type = "switch-to-vt", num = 4 }
        "ctrl-alt-F5"            = { type = "switch-to-vt", num = 5 }
        "ctrl-alt-F6"            = { type = "switch-to-vt", num = 6 }

        # ── Screenshots ──────────────────────────────────────────────────────────────
        # Adjust paths to your screenshot script if ported:
        "shift-Print"            = { type = "exec", exec = ["${screenshot}", "select"] }
        "Print"                  = { type = "exec", exec = ["${screenshot}", "focused"] }
        # Alternate screenshot aliases (Prior/Next = PgUp/PgDown)
        "shift-Prior"            = { type = "exec", exec = ["${screenshot}", "select"] }
        "shift-Next"             = { type = "exec", exec = ["${screenshot}", "focused"] }

        # ── HDR toggle ───────────────────────────────────────────────────────────────
        "ctrl-shift-b"           = { type = "exec", exec = ["jay-toggle-hdr"] }

        # ── Rofi fallback (show actions) ─────────────────────────────────────────────
        "logo-shift-d"           = { type = "exec", exec = ["rofi", "-modi", "drun,run", "-show", "drun", "-drun-show-actions"] }

        # ── Screen recording (gpu-screen-recorder) ───────────────────────────────────
        # Save replay (hold to charge, release to cancel)
        "ctrl-Print"             = { type = "exec", exec = ["sh", "-c", "systemctl --user is-active --quiet gpu-screen-recorder && notify-send -a gpu-screen-recorder 'Saving replay...' && killall -SIGUSR1 gpu-screen-recorder"] }
        "ctrl-shift-Next"        = { type = "exec", exec = ["sh", "-c", "systemctl --user is-active --quiet gpu-screen-recorder && notify-send -a gpu-screen-recorder 'Saving replay...' && killall -SIGUSR1 gpu-screen-recorder"] }

        # ── Compositor control ───────────────────────────────────────────────────────
        "logo-shift-c"           = "reload-config-toml"
        "logo-shift-r"           = "reload-config-so"

        # ── Brightness ───────────────────────────────────────────────────────────────
        XF86MonBrightnessUp      = { type = "exec", exec = ["brightnessctl", "-e4", "-n2", "set", "5%+"] }
        XF86MonBrightnessDown    = { type = "exec", exec = ["brightnessctl", "-e4", "-n2", "set", "5%-"] }

        # ---------------------------------------------------------------------------
        # Resize mode
        # ---------------------------------------------------------------------------
        "logo-r"                 = { type = "push-mode", name = "resize" }

        [modes."resize".shortcuts]
        Left      = [ { type = "resize", dx1 =  100 }, { type = "resize", dx2 = -100 } ]
        Right     = [ { type = "resize", dx1 = -100 }, { type = "resize", dx2 =  100 } ]
        Up        = [ { type = "resize", dy1 =  100 }, { type = "resize", dy2 = -100 } ]
        Down      = [ { type = "resize", dy1 = -100 }, { type = "resize", dy2 =  100 } ]
        Return    = "pop-mode"
        Escape    = "pop-mode"
        "logo-r"  = "pop-mode"

        # -- Volume
        [complex-shortcuts.XF86AudioRaiseVolume]
        mod-mask = ""
        action = { type = "exec", exec = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"] }

        [complex-shortcuts.XF86AudioLowerVolume]
        mod-mask = ""
        action = { type = "exec", exec = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }

        [complex-shortcuts.XF86AudioMute]
        action = { type = "exec", exec = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

        [complex-shortcuts.XF86AudioMicMute]
        action = { type = "exec", exec = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }
      '';
    };
  };
}
