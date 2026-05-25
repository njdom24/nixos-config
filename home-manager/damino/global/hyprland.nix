{ inputs, lib, config, pkgs, ... }: {
  imports = [
    #inputs.hyprland.homeManagerModules.default
    ./wlogout.nix
    ./waybar.nix
    ./rofi.nix
    ./swaync.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    systemd.enable = true;
    # Tempotary config when using overlayed patched Hyprland alongside flake
    package = null;
    #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    #portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    #importantPrefixes = [ "output" ];
    settings = {};

    extraConfig = let
      set-displays = pkgs.writeShellScript "set-displays.sh" ''
        if [[ "$(${pkgs.systemd}/bin/systemctl --user is-active sunshine.service 2>/dev/null)" == "active" ]] || \
           ( [ -f /tmp/sunshine_login ] && \
             ${pkgs.coreutils}/bin/tail -n 200 /tmp/sunshine_login \
               | ${pkgs.gnugrep}/bin/grep -E 'CLIENT (CONNECTED|DISCONNECTED)' \
               | ${pkgs.coreutils}/bin/tail -n 1 \
               | ${pkgs.gnugrep}/bin/grep -q 'CONNECTED' ); then
          $(${pkgs.openrgb}/bin/openrgb --mode static --color 000000 > /dev/null 2>&1 || true) &

          ${pkgs.systemd}/bin/systemctl --user set-environment REMOTE_ENABLED=1

          sleep 1
          # Enable headless display if remote
          hyprctl eval "hl.monitor({ output = \"DP-3\", disabled = false })"
          sleep 1
          hyprctl eval "hl.monitor({ output = \"DP-1\", disabled = true })"
          hyprctl eval "hl.monitor({ output = \"DP-2\", disabled = true })"
          hyprctl eval "hl.monitor({ output = \"HDMI-A-1\", disabled = true })"

          sleep 1 && ${pkgs.hyprland}/bin/hyprctl reload
          sleep 3 && ${pkgs.systemd}/bin/systemctl --user restart sunshine

          exit 0          
        fi

        ${pkgs.systemd}/bin/systemctl --user set-environment REMOTE_ENABLED=0

        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"[workspace 1 silent] firefox\"))"
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"[workspace 4 silent] steam\"))"
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"[workspace 2 silent] discord\"))"
      '';
      # Bodge to work around gamescope cursor grab not working on games with launchers
      gamescope-cursor-fix = pkgs.writeShellScript "gamescope-cursor-fix.sh" ''
        SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

        declare -A gamescopes
        direct_scanout=$(
          ${pkgs.hyprland}/bin/hyprctl getoption render:direct_scanout -j \
          | ${pkgs.jq}/bin/jq -r '.int'
        )

        ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do
          case "$line" in

            openwindow*)
              IFS=',' read -r addr workspace class title <<< "''${line#openwindow>>}"

              if [[ "$class" == "gamescope" || "$class" == "gamescope-wrapped" ]]; then
                gamescopes["$addr"]=1

                # Disable DS when Gamescope is active (work around flicker bug)
                if [[ ''${#gamescopes[@]} -eq 1 ]]; then
                  hyprctl eval "hl.config({ render = { direct_scanout = 0 } })"
                fi

                # Unfocus, refocus to fix stuck cursor
                sleep 0.1

                pre_fullscreen=$(hyprctl -j clients \
                  | ${pkgs.jq}/bin/jq '.[] | select(.focusHistoryID == 0) | .fullscreen')

                hyprctl eval "hl.dispatch(hl.dsp.focus({ last = true }))"
                hyprctl eval "hl.dispatch(hl.dsp.focus({ last = true }))"

                post_fullscreen=$(hyprctl -j clients \
                  | ${pkgs.jq}/bin/jq '.[] | select(.focusHistoryID == 0) | .fullscreen')

                if [[ "$pre_fullscreen" -gt 0 && "$post_fullscreen" -eq 0 ]]; then
                  hyprctl eval "hl.dispatch(hl.dsp.window.fullscreen())"
                fi
              fi
              ;;

            closewindow*)
              addr="''${line#closewindow>>}"

              if [[ -n "''${gamescopes[$addr]}" ]]; then
                unset gamescopes["$addr"]

                # Re-enable DS when all Gamescope instances are closed
                if [[ ''${#gamescopes[@]} -eq 0 ]]; then
                  hyprctl eval "hl.config({ render = { direct_scanout = $direct_scanout } })"
                fi
              fi
              ;;
          esac
        done
      '';
      checkrec = pkgs.writeShellScript "checkrec" ''
        # Check if recording will be started, since GSR doesn't give feedback
        # Get the latest status line from the gpu-screen-recorder journal
        ${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service || exit 1
        last_line=$(${pkgs.systemd}/bin/journalctl --user-unit=gpu-screen-recorder.service -n 50 --no-pager | ${pkgs.gnugrep}/bin/grep -E "Started recording|Stopped recording" | tail -n 1)

        if [[ "$last_line" != *"Started recording"* ]]; then
          ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Starting recording..."
        else
          ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Stopping recording..."
        fi
      '';
      screenshot = pkgs.writeShellScript "screenshot" ''
        mode="$1"
        SCREENSHOT_DIR="$XDG_RUNTIME_DIR/screenshots"
        mkdir -p "$SCREENSHOT_DIR"
        timestamp=$(date +%s)
        tmpfile="$SCREENSHOT_DIR/$timestamp.png"
        scanout=$(${pkgs.hyprland}/bin/hyprctl getoption render:direct_scanout -j | ${pkgs.jq}/bin/jq -r '.int')

        cleanup() {
          rm -f "$tmpfile"
          hyprctl keyword "render:direct_scanout" "$scanout"
        }
        trap cleanup EXIT

        hyprctl keyword "render:direct_scanout" "0"

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
      ''; 
      screenrec = pkgs.writeShellScript "screenrec" ''
        # Check if recording will be started, since GSR doesn't give feedback
        ${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service || exit 1

        # Get the latest status line from the gpu-screen-recorder journal
        last_line=$(${pkgs.systemd}/bin/journalctl --user-unit=gpu-screen-recorder.service -n 50 --no-pager | ${pkgs.gnugrep}/bin/grep -E "Started recording|Stopped recording" | tail -n 1)

        if [[ "$last_line" != *"Started recording"* ]]; then
          ${pkgs.libnotify}/bin/notify-send -a "gpu-screen-recorder" "Recording started"
        fi

        ${pkgs.procps}/bin/pgrep -f "gpu-screen-recorder" | while read pid; do
          cmd=$(${pkgs.ps}/bin/ps -p "$pid" -o args=)

          if [[ "$cmd" == *"-r"* && "$cmd" == *"-ro"* ]]; then
            kill -SIGRTMIN "$pid"
          fi
        done
      '';
    in ''
      -- hyprland.lua
      -- Converted from hyprland.conf (hyprlang) to Lua (Hyprland 0.55+)
      -- Refer to: https://wiki.hypr.land/Configuring/Start/
      
      ---------------------
      ---- MY PROGRAMS ----
      ---------------------
      
      local cursorTheme  = "XCursor-Pro-Dark"
      local fileManager  = "dolphin"
      local mainMod      = "SUPER"
      local menu         = "noctalia msg panel-toggle launcher"
      local terminal     = "alacritty"
      local xdgRuntimeDir = os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000"
      
      ---------------------
      ---- ENVIRONMENT ----
      ---------------------
      
      hl.env("XCURSOR_SIZE",              "24")
      hl.env("HYPRCURSOR_SIZE",           "24")
      hl.env("HYPRCURSOR_THEME",          cursorTheme)
      hl.env("SSH_AUTH_SOCK",  xdgRuntimeDir .. "/gcr/ssh")
      hl.env("SSH_ASKPASS",               "/run/current-system/sw/libexec/seahorse/ssh-askpass")
      hl.env("QT_QPA_PLATFORM",           "wayland;xcb")
      hl.env("GDK_BACKEND",               "wayland,x11")
      hl.env("CLUTTER_BACKEND",           "wayland")
      hl.env("QT_QPA_PLATFORMTHEME",      "qt6ct")
      hl.env("_JAVA_AWT_WM_NONREPARENTING","1")
      hl.env("MOZ_ENABLE_WAYLAND",        "1")
      hl.env("MOZ_DBUS_REMOTE",           "1")
      hl.env("NIXOS_OZONE_WL",            "1")
      hl.env("XDG_MENU_PREFIX",           "plasma-")
      hl.env("AQ_DRM_DEVICES",            "/run/user/1000/dri/dgpu0")
      
      -------------------
      ---- AUTOSTART ----
      -------------------
      
      -- exec-once (run only on Hyprland start)
      hl.on("hyprland.start", function()
          hl.exec_cmd("systemctl --user stop plasma-xdg-desktop-portal-kde")
          hl.exec_cmd("systemctl --user restart xdg-desktop-portal")
          hl.exec_cmd("systemctl --user import-environment PATH")
          hl.exec_cmd("${set-displays}")
          hl.exec_cmd("${gamescope-cursor-fix}")
          hl.exec_cmd("${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh")
          hl.exec_cmd("${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --selection-size-limit 209715200 --reconnect-tries 1 --all-mime-type-regex '(?i)^(?!image/x-inkscape-svg).+'")
          hl.exec_cmd("nm-applet &")
          hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " 24")
          hl.exec_cmd("swaync &")
          hl.exec_cmd("hyprctl dispatch workspace 1")
          hl.exec_cmd("${pkgs.legacy.kdePackages.xwaylandvideobridge}/bin/xwaylandvideobridge")
          hl.exec_cmd('ls "$XDG_RUNTIME_DIR/dri" 2> /dev/null | grep -q dgpu && sleep 2 && systemctl --user restart gpu-screen-recorder')
      
          -- exec (re-run on reload) equivalents — run at start too
          hl.exec_cmd("kill $(pgrep hyprpaper); sleep 1 && ${pkgs.hyprpaper}/bin/hyprpaper &")
          hl.exec_cmd("noctalia")
          hl.exec_cmd("sleep 1; wlr-hdr-cal")
          hl.exec_cmd("sleep 1; systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder")
      end)
      
      --------------------
      ---- MONITORS ----
      --------------------
      
      -- Machine-specific
      require("displays")
      
      hl.monitor({
          output   = "",
          mode     = "preferred",
          position = "auto",
          scale    = 1,
          mirror   = "DP-1",
      })
      
      hl.workspace_rule({ workspace = "1", monitor = "DP-1" })
      hl.workspace_rule({ workspace = "2", monitor = "DP-2" })
      hl.workspace_rule({ workspace = "4", monitor = "DP-1" })
      
      -----------------------
      ---- LOOK AND FEEL ----
      -----------------------
      
      hl.config({
          general = {
              gaps_in          = 2,
              gaps_out         = 4,
              border_size      = 2,
              col = {
                  active_border   = "rgba(${config.colorScheme.palette.base05}ff)",
                  inactive_border = "rgba(${config.colorScheme.palette.base01}ff)",
              },
              resize_on_border = false,
              allow_tearing    = false,
              layout           = "dwindle",
          },
      
          decoration = {
              rounding       = 0,
              rounding_power = 2,
              active_opacity   = 1.0,
              inactive_opacity = 1.0,
              shadow = {
                  enabled      = false,
                  range        = 4,
                  render_power = 3,
                  color        = 0xee1a1a1a,
              },
              blur = {
                  enabled          = true,
                  size             = 2,
                  passes           = 1,
                  contrast         = 2.0,
                  vibrancy         = 0.1696,
                  vibrancy_darkness = 1.0,
              },
          },
      
          animations = {
              enabled = true,
          },
      
          dwindle = {
              force_split          = 2,
              preserve_split       = true,
              split_width_multiplier = 1.3,
          },
      
          master = {
              new_status = "master",
          },
      
          input = {
              kb_layout    = "us",
              follow_mouse = 1,
              sensitivity  = 0,
              accel_profile = "flat",
              touchpad = {
                  natural_scroll = true,
              },
          },
      
          misc = {
              disable_hyprland_logo        = true,
              enable_anr_dialog            = false,
              exit_window_retains_fullscreen = false,
              force_default_wallpaper      = -1,
              screencopy_force_8b          = true,
              vrr                          = 2,
          },
      
          cursor = {
              inactive_timeout   = 10,
              min_refresh_rate   = 48,
              no_break_fs_vrr    = 2,
              no_hardware_cursors = 0,
              no_warps           = false,
          },
      
          debug = {
              full_cm_proto = true,
          },
      
          render = {
              cm_auto_hdr      = 1,
              cm_sdr_eotf      = 2,
              direct_scanout   = 2,
              non_shader_cm    = 1,
              send_content_type = 0,
          },
      
          quirks = {
              prefer_hdr               = 2,
              skip_non_kms_dmabuf_formats = true,
          },
      
          xwayland = {
              force_zero_scaling = true,
          },
      })
      
      -- debug:disable_scale_checks
      hl.config({ debug = { disable_scale_checks = true } })
      
      ------------------
      ---- BEZIERS ----
      ------------------
      
      hl.curve("easeOutQuint",    { type = "bezier", points = { {0.23, 1},    {0.32, 1}  } })
      hl.curve("easeInOutCubic",  { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}  } })
      hl.curve("linear",          { type = "bezier", points = { {0, 0},       {1, 1}     } })
      hl.curve("almostLinear",    { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}  } })
      hl.curve("quick",           { type = "bezier", points = { {0.15, 0},    {0.1, 1}   } })
      
      --------------------
      ---- ANIMATIONS ----
      --------------------
      
      hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
      hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
      hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, bezier = "easeOutQuint" })
      hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
      hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
      hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
      hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
      hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
      hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
      hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "quick",        style = "slide" })
      hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "quick",        style = "slide" })
      hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
      hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
      hl.animation({ leaf = "workspaces",    enabled = true,  speed = 0.94, bezier = "almostLinear", style = "fade" })
      hl.animation({ leaf = "workspacesIn",  enabled = false, speed = 1.21, bezier = "almostLinear", style = "fade" })
      hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 0.94, bezier = "almostLinear", style = "fade" })
      
      -----------------
      ---- DEVICES ----
      -----------------
      
      hl.device({
          name    = "dualsense-wireless-controller-touchpad",
          enabled = false,
      })
      
      --------------------
      ---- GESTURES ----
      --------------------
      
      hl.gesture({
          fingers   = 3,
          direction = "horizontal",
          action    = "workspace",
      })
      
      ----------------------
      ---- LAYER RULES ----
      ----------------------
      
      hl.layer_rule({ name = "sel-no-anim",      match = { namespace = "selection" },                   no_anim = true })
      hl.layer_rule({ name = "swaync-notif-blur",match = { namespace = "swaync-notification-window" },  blur = true, ignore_alpha = 0.5 })
      hl.layer_rule({ name = "swaync-cc-blur",   match = { namespace = "swaync-control-center" },       blur = true, ignore_alpha = 0.5 })
      hl.layer_rule({ name = "rofi-blur",        match = { namespace = "rofi" },                        blur = true, ignore_alpha = 0.5 })
      hl.layer_rule({ name = "waybar-blur",      match = { namespace = "waybar" },                      blur = true, ignore_alpha = 0.5 })
      
      ----------------------
      ---- WINDOW RULES ----
      ----------------------

      -- Smart gaps
      hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
      hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
      hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
      hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0 })
      hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
      hl.window_rule({ match = { float = false, workspace = "f[1]" }, rounding = 0 })
      
      -- Suppress maximize for all windows
      hl.window_rule({
          name           = "suppress-maximize",
          match          = { class = ".*" },
          suppress_event = "maximize",
      })
      
      -- xwaylandvideobridge — invisible overlay window
      hl.window_rule({
          name             = "xwaylandvideobridge",
          match            = { class = "^(xwaylandvideobridge)$" },
          opacity          = 0.0,
          no_anim          = true,
          no_initial_focus = true,
          max_size         = { 1, 1 },
          no_blur          = true,
          no_focus         = true,
      })
      
      -- Game content type
      hl.window_rule({ name = "moonlight-game",   match = { class = "^(com.moonlight_stream.Moonlight)$" }, content = "game" })
      hl.window_rule({ name = "gamescope-game",   match = { class = "^gamescope$" },                        content = "game" })
      hl.window_rule({ name = "gamescope-wrap",   match = { class = "^.gamescope-wrapped$" },               content = "game" })
      hl.window_rule({ name = "steam-app-game",   match = { class = "^(steam_app_%d+)$" },                  content = "game" })
      
      -- Steam rules
      hl.window_rule({
          name           = "steam-no-focus",
          match          = { class = "^(steam)$" },
          no_initial_focus = true,
          no_blur        = true,
          suppress_event = "activate",
      })
      hl.window_rule({
          name           = "steam-suppress-activatefocus",
          match          = { class = "^(steam)$" },
          suppress_event = "activatefocus",
      })
      hl.window_rule({
          name    = "steam-empty-title-float",
          match   = { class = "^(steam)$", title = "^$", float = true },
          no_blur = true,
          no_anim = true,
      })
      hl.window_rule({
          name      = "steam-big-picture",
          match     = { title = "^(Steam Big Picture Mode)$" },
          fullscreen = true,
      })
      hl.window_rule({
          name  = "steam-non-main-float",
          match = { class = "^(steam)$", title = "negative:^(Steam)$" },
          float = true,
      })
      
      -- App workspace assignments
      hl.window_rule({ name = "vesktop-ws2",  match = { class = "^(vesktop)$" }, workspace = "2 silent" })
      hl.window_rule({ name = "discord-ws2",  match = { class = "^(discord)$" }, workspace = "2 silent" })
      hl.window_rule({ name = "steam-ws4",    match = { class = "^(steam)$" },   workspace = "4 silent" })
      
      -- Blank class/title — no blur
      hl.window_rule({
          name    = "blank-class-title-no-blur",
          match   = { class = "^$", title = "^$" },
          no_blur = true,
      })
      
      ---------------------
      ---- KEYBINDINGS ----
      ---------------------
      
      -- Core
      hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))
      hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
      
      -- Focus
      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left"  }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up"    }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down"  }))
      
      -- Cycle tiled/floating (preserves original logic via exec)
      hl.bind(mainMod .. " + space", function()
          local w = hl.get_active_window()
          if w ~= nil and w.floating then
              hl.dispatch(hl.dsp.window.cycle_next({ floating = false }))
          else
              hl.dispatch(hl.dsp.window.cycle_next({ floating = true }))
          end
      end)
      
      -- Move windows
      hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left"  }))
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up"    }))
      hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down"  }))
      
      -- Workspaces 1–10
      for i = 1, 10 do
          local key = tostring(i % 10)
          hl.bind(mainMod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
          hl.bind(mainMod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i, follow = false }))
      end
      
      -- Alt+Tab
      hl.bind("ALT + Tab", function()
          hl.dispatch(hl.dsp.window.cycle_next())
          hl.dispatch(hl.dsp.window.bring_to_top())
      end)
      
      -- Notifications / panels
      hl.bind("CTRL + SPACE", hl.dsp.exec_cmd("noctalia msg notification-clear-active"))
      hl.bind("CTRL + grave",  hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"))
      
      -- Screenshots
      hl.bind("Print",       hl.dsp.exec_cmd("${screenshot} focused"))
      hl.bind("SHIFT + Next",  hl.dsp.exec_cmd("${screenshot} focused"))
      hl.bind("SHIFT + Print", hl.dsp.exec_cmd("${screenshot} selector"))
      hl.bind("SHIFT + Prior", hl.dsp.exec_cmd("${screenshot} selector"))
      
      -- GPU screen recorder (save replay — bindo equivalent: only fires when service active)
      hl.bind("CTRL + Print",       hl.dsp.exec_cmd("systemctl --user is-active --quiet gpu-screen-recorder.service && notify-send -a 'gpu-screen-recorder' 'Saving replay...'"))
      hl.bind("CTRL + Print",       hl.dsp.exec_cmd("systemctl --user is-active --quiet gpu-screen-recorder.service && killall -SIGUSR1 gpu-screen-recorder"), { long_press = true })
      hl.bind("CTRL + SHIFT + Next",  hl.dsp.exec_cmd("systemctl --user is-active --quiet gpu-screen-recorder.service && notify-send -a 'gpu-screen-recorder' 'Saving replay...'"))
      hl.bind("CTRL + SHIFT + Next",  hl.dsp.exec_cmd("systemctl --user is-active --quiet gpu-screen-recorder.service && killall -SIGUSR1 gpu-screen-recorder"), { long_press = true })

      hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("${checkrec}"))
      hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("${screenrec}"), { long_press = true })
      hl.bind("CTRL + SHIFT + Prior", hl.dsp.exec_cmd("${checkrec}"))
      hl.bind("CTRL + SHIFT + Prior", hl.dsp.exec_cmd("${screenrec}"), { long_press = true })
      
      -- HDR toggle
      hl.bind("CTRL + SHIFT + B", hl.dsp.exec_cmd("hypr-toggle-hdr"))
      
      -- Volume / brightness (locked = works on lockscreen, repeating = held key repeats)
      hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),      { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),           { locked = true, repeating = true })
      hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),          { locked = true })
      hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),        { locked = true })
      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
      
      -- Mouse drag/resize
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
      
      -----------------------
      ---- RESIZE SUBMAP ----
      -----------------------
       
      hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

      hl.define_submap("resize", function()

          -- Set repeating binds for resizing the active window.
          hl.bind("right", hl.dsp.window.resize({ x = 100, y = 0, relative = true}), { repeating = true })
          hl.bind("left", hl.dsp.window.resize({ x = -100, y = 0, relative = true}), { repeating = true })
          hl.bind("up", hl.dsp.window.resize({ x = 0, y = 100, relative = true}), { repeating = true })
          hl.bind("down", hl.dsp.window.resize({ x = 0, y = -100, relative = true}), { repeating = true })

          -- Use `reset` to go back to the global submap
          hl.bind("escape", hl.dsp.submap("reset"))

          -- Exit resize mode (depends on https://github.com/hyprwm/Hyprland/pull/14578)
          -- hl.bind(mainMod .. " + R", hl.dsp.submap("reset"))
      end)
    '';
  };

  services = {
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        wallpaper = [
          {
            monitor = "";
            path = "${./theming/wallpapers/new_gridania.jpg}";
            fit_mode = "cover";
          }
        ];
      };
    };
  };
  systemd.user.services.hyprpaper = lib.mkForce { };

  xdg.portal.extraPortals = [ config.wayland.windowManager.hyprland.portalPackage ];
  xdg.portal.config = {
    hyprland = {
      #preferred = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
      #};
    };
  };

  home = {
    file = {
      ".config/hypr/xdph.conf" = let screenshare-fix =
         let portal-watcher = pkgs.writeShellScript "portal-watcher.sh" ''
           #! /usr/bin/env bash
           ${pkgs.pipewire}/bin/pw-mon | while read -r line; do
             if [[ "$line" == *"Stream/Input/Video"* ]]; then
               streaming_sources=$(${pkgs.pipewire}/bin/pw-dump | ${pkgs.gnugrep}/bin/grep -o Stream/Input/Video | ${pkgs.coreutils}/bin/wc -l)
               if [[ "$streaming_sources" == "0" ]]; then
                 HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)

                 if [[ -z "$HEADLESS" ]]; then
                   echo "No headless output found. Ignoring" >&2
                 else
                   ${pkgs.sway}/bin/swaymsg output "$HEADLESS" unplug > /dev/null 2>&1 &
                 fi

                 ${pkgs.systemd}/bin/systemctl --user stop hypr-screenshare-mirror 2> /dev/null || true
                 exit 0
               fi
             fi
           done
         ''; 
         in pkgs.writeShellScript "screenshare-fix.sh" ''
           #! /usr/bin/env bash
           # Example outputs:
           # [SELECTION]/screen:DP-2
           # [SELECTION]/window:447338992
           # [SELECTION]/region:DP-1@697,422,953,722

           if [[ "$XDG_CURRENT_DESKTOP" != "sway" ]]; then
             hyprland-share-picker
             exit 0
           fi

           # Run the real command with all args, capture stdout
           display="$(${pkgs.slurp}/bin/slurp -f '%o' -or)"

           if [[ "$display" != "HEADLESS-"* ]]; then
             # Create headless display to avoid direct scanout stutter: https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/5173
             #   and get tonemapping when toggling HDR
             # Or maybe https://github.com/waycrate/wayshot/issues/181 when xdg-desktop-portal-luminous takes this,
             #   but libwayshot uses libplacebo's bt.2390 instead of gamma,param=2.2

             HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
             if [[ -z "$HEADLESS" ]]; then
               echo "No headless output found, creating one..." >&2
               ${pkgs.sway}/bin/swaymsg create_output > /dev/null 2>&1 &
               HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
               sleep 0.5
             fi

             DISPLAY_INFO=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$display\")")
             # Get resolution, scale, and refresh rate
             WIDTH=$(${pkgs.jq}/bin/jq   -r '.current_mode.width'   <<< "$DISPLAY_INFO")
             HEIGHT=$(${pkgs.jq}/bin/jq  -r '.current_mode.height'  <<< "$DISPLAY_INFO")
             REFRESH=$(${pkgs.jq}/bin/jq -r '.current_mode.refresh' <<< "$DISPLAY_INFO")
             SCALE=$(${pkgs.jq}/bin/jq   -r '.scale'  <<< "$DISPLAY_INFO")
             XPOS=$(${pkgs.jq}/bin/jq    -r '.rect.x' <<< "$DISPLAY_INFO")
             YPOS=$(${pkgs.jq}/bin/jq    -r '.rect.y' <<< "$DISPLAY_INFO")
             REFRESH=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.3f\", $REFRESH / 1000 }")

             # Apply settings to headless output
             ${pkgs.sway}/bin/swaymsg output $HEADLESS mode "$WIDTH"x"$HEIGHT"@"$REFRESH"Hz enable pos "$XPOS" "$YPOS" scale "$SCALE" > /dev/null 2>&1 &

             # r: Treat as allow_token_by_default=true
             #echo "[SELECTION]r/screen:$HEADLESS"
             echo "[SELECTION]/screen:$HEADLESS"

             ${pkgs.systemd}/bin/systemctl --user stop hypr-screenshare-mirror 2> /dev/null || true
             ${pkgs.systemd}/bin/systemctl --user reset-failed
             ${pkgs.systemd}/bin/systemd-run --user --unit=hypr-screenshare-mirror ${portal-watcher}
           else
             echo "[SELECTION]/screen:$display"
           fi

           exit 0
        ''; in lib.mkDefault {
        text = ''
          screencopy {
            max_fps = 60
            allow_token_by_default = true
            custom_picker_binary = ${screenshare-fix}
          }
        '';
      };

      ".config/hypr/hm/displays.conf" = lib.mkDefault {
        text = ''
          # Default monitor configuration
          monitor=,preferred,auto,auto
          exec = timeout 10 kanshi &
        '';
      };
    };
    packages = with pkgs; [
      #hyprlandPlugins.hy3
      hyprsunset
      wl-mirror
    ] ++ [
      (pkgs.writeShellScriptBin "hypr-toggle-hdr" ''
        #!/usr/bin/env bash

        monitor=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.focused==true).name")
        # Find the sysfs path to EDID dynamically under card*
        edid_path=""
        for card in /sys/class/drm/card*; do
          candidate="$card-$monitor/edid"
          if [ -f "$candidate" ]; then
            edid_path="$candidate"
            break
          fi
        done
      
        if [ -z "$edid_path" ]; then
          echo "EDID file not found for monitor $monitor under any card* directory."
          exit 1
        fi
      
        if ${pkgs.edid-decode}/bin/edid-decode < "$edid_path" | ${pkgs.gnugrep}/bin/grep -q "HDR Static Metadata Data Block"; then
          echo "HDR support detected on $monitor"

          current_mode="$(hyprctl monitors -j \
            | ${pkgs.jq}/bin/jq -r --arg monitor "$monitor" '.[] | select(.name == $monitor) | .colorManagementPreset')"

          case "$1" in
            on)
              if [ "$current_mode" = "hdr" ]; then
                echo "Already in HDR mode; reapplying."
              else
                echo "Enabling HDR"
              fi

              #hyprctl keyword "monitorv2[$monitor]:cm" hdr
              hyprctl eval "hl.monitor({ output = \"$monitor\", cm = \"hdr\" })"
              #hyprctl --batch "keyword monitorv2[$monitor]:cm hdr ; keyword monitorv2[$monitor]:bitdepth 10"
              ;;
            off)
              if [ "$current_mode" = "srgb" ]; then
                echo "Already in sRGB mode; nothing to do."
                exit 0
              fi
              echo "Disabling HDR"
              hyprctl eval "hl.monitor({ output = \"$monitor\", cm = \"srgb\" })"
              ;;
            *)
              if [ "$current_mode" = "hdr" ]; then
                echo "Toggling: disabling HDR"
                hyprctl eval "hl.monitor({ output = \"$monitor\", cm = \"srgb\" })"
              else
                echo "Toggling: enabling HDR"
                hyprctl eval "hl.monitor({ output = \"$monitor\", cm = \"hdr\" })"
              fi
              ;;
          esac

          sleep 1 && systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder

        else
          echo "HDR not supported on $monitor; no changes made."
        fi
      '')
    ];

    activation = {
      hyprland-displays-writeable = lib.hm.dag.entryAfter ["onFilesChange"] ''
        #!/usr/bin/env bash
        src="${config.home.homeDirectory}/.config/hypr/hm/"
        dest="${config.home.homeDirectory}/.config/hypr/"
        
        # Copy new files, preserving directory structure, skipping existing
        ${pkgs.rsync}/bin/rsync -aL --ignore-existing --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r "$src" "$dest"
      '';
    };
  };
}
