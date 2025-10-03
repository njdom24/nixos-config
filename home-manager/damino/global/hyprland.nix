{ inputs, lib, config, pkgs, ... }: {
  imports = [
    inputs.hyprland.homeManagerModules.default
    ./wlogout.nix
    ./waybar.nix
    ./rofi.nix
    ./swaync.nix
  ];

  wayland.windowManager.hyprland =
  let
    set-displays = pkgs.writeShellScript "set-displays.sh" ''
      if [ -f /tmp/sunshine_login ]; then
        if ${pkgs.gawk}/bin/awk '
        /CLIENT CONNECTED/ {e=1}
        e && /CLIENT DISCONNECTED/ {cancel=1}
        END { if (e && !cancel) exit 0; else exit 1 }
        ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/sunshine_login); then
          ${pkgs.openrgb}/bin/openrgb --mode static --color 000000 2> /dev/null || true

          # Enable headless display if remote
          ${pkgs.hyprland}/bin/hyprctl keyword monitor HDMI-A-1, 1920x1080@60,0x0,1
          ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-1, disable
          ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2, disable
          ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-3, disable

          sleep 5 && systemctl --user start sunshine

          exit 0          
        fi
      fi

      # Restore desktop config if not remote
      display_cfg="/home/$USER/.config/hypr/displays.conf"
      if [[ -f "$display_cfg".gsc ]]; then
        mv "$display_cfg".gsc "$displays"
      fi
      ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 1 silent] firefox"
      ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 2 silent] discord"
      ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 4 silent] steam"
    '';
    # Bodge to work around gamescope cursor grab not working on games with launchers
    gamescope-cursor-fix = pkgs.writeShellScript "gamescope-cursor-fix.sh" ''
      SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      
      ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do
        if [[ "$line" =~ ^openwindow.*gamescope ]]; then
          # wait a moment to ensure window is mapped
          sleep 0.1
          # move to temp workspace 11, then back to current
          current_ws=$(${pkgs.hyprland}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.id')
          ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent 11,class:gamescope
          sleep 0.05
          ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent "$current_ws",class:gamescope
          ${pkgs.hyprland}/bin/hyprctl dispatch focuswindow class:gamescope
        fi
      done
    '';
  in {
    enable = true;
    systemd.enable = true;
    #importantPrefixes = [ "output" ];
    #plugins = [ pkgs.hyprlandPlugins.hy3 ];
    #plugins = [ inputs.hy3.packages.x86_64-linux.hy3 ];
    settings = {
      "$mainMod" = "SUPER";
      # Kanshi handles non-HDR stuff
      source = "~/.config/hypr/displays.conf";

      "$terminal" = "kitty";
      "$fileManager" = "dolphin";
      "$menu" = "rofi -modi 'drun,run' -theme ~/.local/share/rofi/themes/custom.rasi -show drun";
      "$cursorTheme" = "XCursor-Pro-Dark";

      ### ENVIRONMENT VARIABLES ###
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
        "HYPRCURSOR_THEME,$cursorTheme"
        "SSH_AUTH_SOCK,$XDG_RUNTIME_DIR/gcr/ssh"
        "SSH_ASKPASS,/run/current-system/sw/libexec/seahorse/ssh-askpass"
        "QT_QPA_PLATFORM,wayland;xcb"
        "GDK_BACKEND,wayland,x11"
        "CLUTTER_BACKEND,wayland"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "_JAVA_AWT_WM_NONREPARENTING,1"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_DBUS_REMOTE,1"
        "NIXOS_OZONE_WL,1"
        "REMOTE_ENABLED,0"
      ];

      #plugin = {
        #hy3 = {
        #  autotile.enable = true;
        #};
      #};

      general = {
        gaps_in = 3;
        gaps_out = 6;
        border_size = 1;
        # https://wiki.hypr.land/Configuring/Variables/#variable-types for info about colors
        "col.active_border" = "rgba(${config.colorScheme.palette.base05}ff)";
        "col.inactive_border" = "rgba(${config.colorScheme.palette.base01}ff)";
        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false;
        # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
        layout = "dwindle";
        #layout = "hy3";
      };

      decoration = {
        rounding = 0;
        rounding_power = 2;
        # Change transparency of focused and unfocused windows
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow = {
          enabled = false;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        # https://wiki.hypr.land/Configuring/Variables/#blur
        # Screen transitions look weird with blur enabled
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, quick, slide"
          "layersOut, 1, 1.5, quick, slide"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];
      };

      workspace = [
        "w[tv1], gapsout:0, gapsin:0"
        "f[1], gapsout:0, gapsin:0"
      ];

      windowrule = [
        "bordersize 0, floating:0, onworkspace:w[tv1]"
        "rounding 0, floating:0, onworkspace:w[tv1]"
        "bordersize 0, floating:0, onworkspace:f[1]"
        "rounding 0, floating:0, onworkspace:f[1]"
        # # Ignore maximize requests from apps
        "suppressevent maximize, class:.*"
        # XWaylandVideoBridge
        "opacity 0.0 override, class:^(xwaylandvideobridge)$"
        "noanim, class:^(xwaylandvideobridge)$"
        "noinitialfocus, class:^(xwaylandvideobridge)$"
        "maxsize 1 1, class:^(xwaylandvideobridge)$"
        "noblur, class:^(xwaylandvideobridge)$"
        "nofocus, class:^(xwaylandvideobridge)$"

        # Fix some dragging issues with XWayland
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        "content game, class:^gamescope$"
        "content game, class:^(steam_app_\d+)$" # All Steam apps are considered games
        # Help deal with gamescope input going through to Steam
        #"stayfocused, class:^gamescope$"
        "noinitialfocus, class:^(steam)$"
        "fullscreen, title:^(Steam Big Picture Mode)$"
        #"suppressevent fullscreen maximize, title:^(Steam Big Picture Mode)$"

        "workspace 2 silent, class:^(vesktop)$"
        "workspace 2 silent, class:^(discord)$"

        "workspace 4 silent, class:^(steam)$"

        # Temporary(?) blur workspace change glitching workaround
        "noblur,class:^()$,title:^()$"
      ];

      layerrule = [
        # Don't clobber slurp's overlay window
        "noanim, selection"
        # https://github.com/ErikReider/SwayNotificationCenter/issues/424#issuecomment-2694101051
        "blur, swaync-notification-window"
        "ignorealpha 0.5, swaync-notification-window"
        "blur, swaync-control-center"
        "ignorealpha 0.5, swaync-control-center"
        "blur, rofi"
        "ignorealpha 0.5, rofi"
        "blur, waybar"
        "ignorealpha 0.5, waybar"
      ];

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2; # Split to right, down
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1; # Disable anime mascot wallpapers
        disable_hyprland_logo = true; # If true disables the random hyprland logo / anime girl background
        enable_anr_dialog = false; # Disable "not responding" popups
        exit_window_retains_fullscreen = false; # Steam Big Picture retain fullscreen on game exit
        vrr = 2;
        screencopy_force_8b = true;
      };

      render = {
        direct_scanout = 1;
        cm_fs_passthrough = 2;
        cm_auto_hdr = 1;
      };

      #debug = {
      #  full_cm_proto = true;
      #};

      ### INPUT ###

      input = {
        kb_layout = "us";
        #kb_variant = "";
        #kb_model = "";
        #kb_options = "";
        #kb_rules = "";
        follow_mouse = 1;
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        touchpad = {
          natural_scroll = true;
        };
      };

      gesture = [
        "3, horizontal, workspace"
      ];

      cursor = {
        no_warps = false;
        inactive_timeout = 10;
        # https://github.com/hyprwm/Hyprland/discussions/7386
        no_break_fs_vrr = 2;
        no_hardware_cursors = 0;
        min_refresh_rate = 72;
      };

      device = [
        {
          name = "dualsense-wireless-controller-touchpad";
          enabled = false;
        }
      ];

      ### KEYBINDINGS ###
      bind = let
      checkrec = pkgs.writeShellScript "checkrec" ''
        # Check if recording will be started, since GSR doesn't give feedback
        # Get the latest status line from the gpu-screen-recorder journal
        last_line=$(${pkgs.systemd}/bin/journalctl --user-unit=gpu-screen-recorder.service -n 50 --no-pager | ${pkgs.gnugrep}/bin/grep -E "Started recording|Stopped recording" | tail -n 1)

        if [[ "$last_line" != *"Started recording"* ]]; then
          ${pkgs.libnotify}/bin/notify-send "Starting recording..."
        else
          ${pkgs.libnotify}/bin/notify-send "Stopping recording..."
        fi
      '';
      screenshot = pkgs.writeShellScript "screenshot" ''
        mode="$1"
        tmpfile=$(${pkgs.mktemp}/bin/mktemp)
        trap 'rm -f "$tmpfile"' EXIT

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
          ${pkgs.wl-clipboard-rs}/bin/wl-copy --type image/png < "$tmpfile"
          # cat "$tmpfile" | ${pkgs.wl-clipboard-rs}/bin/wl-copy --type image/png
          ${pkgs.libnotify}/bin/notify-send -i "$tmpfile" "Screenshot taken"
        fi
      ''; in [
        "$mainMod, Return, exec, $terminal"
        "$mainMod SHIFT, Q, killactive,"
        "$mainMod SHIFT, E, exec, wlogout"
        "$mainMod SHIFT, Space, togglefloating,"
        "$mainMod, D, exec, $menu"
        # $mainMod, H, togglesplit, # dwindle
        "$mainMod, F, fullscreen"
        #"$mainMod, left, hy3:movefocus, l"
        #"$mainMod, right, hy3:movefocus, r"
        #"$mainMod, up, hy3:movefocus, u"
        #"$mainMod, down, hy3:movefocus, d"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        #"$mainMod, H, hy3:makegroup, h"
        #"$mainMod, V, hy3:makegroup, v"
        "$mainMod, space, exec, $(hyprctl activewindow -j | jq '.floating') && hyprctl dispatch cyclenext tiled || hyprctl dispatch cyclenext floating"
        #"$mainMod, space, hy3:togglefocuslayer, nowarp"

        # Move the active window (use SHIFT as the extra modifier)
        #"$mainMod SHIFT, left,  hy3:movewindow, l"
        #"$mainMod SHIFT, right, hy3:movewindow, r"
        #"$mainMod SHIFT, up,    hy3:movewindow, u"
        #"$mainMod SHIFT, down,  hy3:movewindow, d"
        "$mainMod SHIFT, left,  movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up,    movewindow, u"
        "$mainMod SHIFT, down,  movewindow, d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
        "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, movetoworkspacesilent, 10"

        # Standard Alt+Tab behavior, useful for Steam Input
        "ALT, Tab, cyclenext"
        "ALT, Tab, bringactivetotop"

        # Notification daemon
        "CTRL, SPACE, exec, swaync-client --hide-latest"
        "CTRL, grave, exec, swaync-client --toggle-panel"

        # Screenshot active monitor of focused window
        ", Print, exec, ${screenshot} focused"
        "SHIFT, Next, exec, ${screenshot} focused"      
        
        # Screenshot selected region
        "SHIFT, Print, exec, ${screenshot} selector"
        "SHIFT, Prior, exec, ${screenshot} selector"

        # Save replay if gpu-screen-recorder -r is running
        "CTRL, Print, exec, ${pkgs.libnotify}/bin/notify-send 'Saving replay...'"
        "CTRL SHIFT, Next, exec, ${pkgs.libnotify}/bin/notify-send 'Saving replay...'" # Page Down

        # Start / stop manual recording if gpu-screen-recorder -ro is running
        "CTRL SHIFT, Print, exec, ${checkrec}"
        "CTRL SHIFT, Prior, exec, ${checkrec}" # Page Up

        "CTRL SHIFT, B, exec, hypr-toggle-hdr"
      ];

      bindo = let
        screenrec = pkgs.writeShellScript "screenrec" ''
          # Check if recording will be started, since GSR doesn't give feedback
          # Get the latest status line from the gpu-screen-recorder journal
          last_line=$(${pkgs.systemd}/bin/journalctl --user-unit=gpu-screen-recorder.service -n 50 --no-pager | ${pkgs.gnugrep}/bin/grep -E "Started recording|Stopped recording" | tail -n 1)

          if [[ "$last_line" != *"Started recording"* ]]; then
            ${pkgs.libnotify}/bin/notify-send "Recording started"
          fi

          ${pkgs.procps}/bin/pgrep -f "gpu-screen-recorder" | while read pid; do
            cmd=$(${pkgs.ps}/bin/ps -p "$pid" -o args=)

            if [[ "$cmd" == *"-r"* && "$cmd" == *"-ro"* ]]; then
              kill -SIGRTMIN "$pid"
            fi
          done
        '';
      in  [
        # Save replay if gpu-screen-recorder -r is running
        "CTRL, Print, exec, killall -SIGUSR1 gpu-screen-recorder"
        "CTRL SHIFT, Next, exec, killall -SIGUSR1 gpu-screen-recorder" # Page Down
        # Start / stop manual recording if gpu-screen-recorder -ro is running
        "CTRL SHIFT, Print, exec, ${screenrec}"
        "CTRL SHIFT, Prior, exec, ${screenrec}" # Page Up
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      bindl = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        #",XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%"
        #",XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%"
        #",XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle"
        #",XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SINK@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      xwayland = {
        force_zero_scaling = true;
      };

      experimental = {
        # https://github.com/hyprwm/Hyprland/discussions/11677#discussioncomment-14397277
        # Despite above, still needed for auto HDR in gamescope as of 9/14/2025. Maybe since I'm not using VK_hdr_layer
        xx_color_management_v4 = true;
      };

      ### AUTOSTART ###
      exec-once = [
        "${set-displays}"
        "${gamescope-cursor-fix}"
        "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)"
        # 200 MiB limit
        "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --selection-size-limit 209715200 --reconnect-tries 1 --all-mime-type-regex '(?i)^(?!image/x-inkscape-svg).+'"
        "nm-applet &"
        # Work around cursor config option unreliability
        "hyprctl setcursor $cursorTheme 24"
        "swaync &"
        #"[workspace 1 silent] firefox"
        #"[workspace 2 silent] discord"
        #"[workspace 4 silent] steam"
        "hyprctl dispatch workspace 1"
        "${pkgs.kdePackages.xwaylandvideobridge}/bin/xwaylandvideobridge"
      ];
      exec = [
        "${pkgs.hyprpaper}/bin/hyprpaper &"
        #"timeout 10 kanshi &"
        # Waybar freezes on reload on Hyprland sometimes, so just restart
        "kill `pgrep waybar`; waybar &"

        "sleep 1; systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder"
      ];
    };

    extraConfig = ''
      #plugin = ${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so
      #plugin = $inputs.hy3.packages.x86_64-linux.hy3}/lib/libhy3.so
      debug:disable_scale_checks = true
      ## Resize mode/submap
      bind=$mainMod,R,submap,resize
      submap=resize
          unbind = ,down
          binde = , right, resizeactive,  100 0
          binde = , left,  resizeactive, -100 0
          binde = , down,  resizeactive,  0 100
          binde = , up,    resizeactive,  0 -100
          binde = SHIFT, right, resizeactive,  10 0
          binde = SHIFT, left,  resizeactive, -10 0
          binde = SHIFT, down,  resizeactive,  0 10
          binde = SHIFT, up,    resizeactive,  0 -10
          bind=SUPER,R,submap,reset
          #bind = , escape,submap,reset 
          #bind = , return,submap,reset 
      submap=reset
    '';
  };

  services = {
    hyprpaper = {
      enable = true;
      settings = {
        preload = [ "${./theming/wallpapers/new_gridania.jpg}" ];
        wallpaper = ",${./theming/wallpapers/new_gridania.jpg}";
      };
    };
  };
  systemd.user.services.hyprpaper = lib.mkForce { };

  home = {
    file = {
      ".config/xdg-desktop-portal/hyprland-portals.conf" = lib.mkDefault {
        text = ''
          [preferred]
          default = hyprland;gtk
          org.freedesktop.impl.portal.FileChooser = kde
        '';
      };

      ".config/hypr/xdph.conf" = lib.mkDefault {
        text = ''
          screencopy {
            max_fps = 60
            allow_token_by_default = true
            custom_picker_binary = hyprland-share-picker
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
      
        if ${pkgs.edid-decode}/bin/edid-decode < "$edid_path" | grep -q "HDR Static Metadata Data Block"; then
          echo "HDR support detected on $monitor"

          conf="$HOME/.config/hypr/displays.conf"
          if [ -w "$conf" ]; then
            echo "test"
            current_mode=$(${pkgs.gawk}/bin/awk -v mon="$monitor" '
              BEGIN { inblock=0; has_output=0; mode="unknown" }
              /^[[:space:]]*monitorv2[[:space:]]*\{/ { inblock=1; has_output=0; mode="unknown"; next }
              /^[[:space:]]*\}/ {
                if (inblock && has_output && mode != "unknown") { print mode; exit }
                inblock=0
              }
              inblock {
                if ($0 ~ ("output = " mon)) has_output=1
                if ($0 ~ /cm = (srgb|hdr)/) {
                  split($0, a, "=")
                  mode=a[2]; gsub(/[[:space:]]/, "", mode)
                }
              }
            ' "$conf")
      
            case "$1" in
              on)
                if [ "$current_mode" = "hdr" ]; then
                  echo "Already in HDR mode; nothing to do."
                  exit 0
                fi
                echo "Enabling HDR"
                ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
                  /output = $monitor/,/}/s/cm = srgb/cm = hdr/
                }" "$conf"
                ;;
              off)
                if [ "$current_mode" = "srgb" ]; then
                  echo "Already in sRGB mode; nothing to do."
                  exit 0
                fi
                echo "Disabling HDR"
                ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
                  /output = $monitor/,/}/s/cm = hdr/cm = srgb/
                }" "$conf"
                ;;
              *)
                if [ "$current_mode" = "hdr" ]; then
                  echo "Toggling: disabling HDR"
                  ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
                    /output = $monitor/,/}/s/cm = hdr/cm = srgb/
                  }" "$conf"
                else
                  echo "Toggling: enabling HDR"
                  ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
                    /output = $monitor/,/}/s/cm = srgb/cm = hdr/
                  }" "$conf"
                fi
                ;;
            esac
          else
            # Query monitor state
            state=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$monitor\")")
            
            format=$(echo "$state" | ${pkgs.jq}/bin/jq -r ".currentFormat")
            
            ### HDR / SDR toggle (bitdepth + cm)
            if [[ "$format" == "XRGB8888" ]]; then
                echo "Switching $monitor to HDR"
                ${pkgs.hyprland}/bin/hyprctl keyword "monitorv2[$monitor]:bitdepth" 10
                ${pkgs.hyprland}/bin/hyprctl keyword "monitorv2[$monitor]:cm" hdr
            elif [[ "$format" == "XRGB2101010" ]]; then
                echo "Switching $monitor to SDR"
                ${pkgs.hyprland}/bin/hyprctl keyword "monitorv2[$monitor]:bitdepth" 8
                ${pkgs.hyprland}/bin/hyprctl keyword "monitorv2[$monitor]:cm" srgb
            else
                echo "Unknown format: $format"
            fi
          fi

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
