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
      display_cfg="/home/$USER/.config/hypr/displays.conf"

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
        # Hyprctl is unreliable and extremely buggy for disabling
        #${pkgs.hyprland}/bin/hyprctl keyword monitor HDMI-A-1, 1920x1080@60,0x0,1
        #sleep 1
        #${pkgs.hyprland}/bin/hyprctl keyword monitor DP-1, disable
        #${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2, disable
        #${pkgs.hyprland}/bin/hyprctl keyword monitor DP-3, disable

        if [[ ! -f "$display_cfg".gsc ]]; then
          # Make backup
          cp -f "$display_cfg" "$display_cfg".gsc
        fi

        tmpfile=$(${pkgs.mktemp}/bin/mktemp)

        ${pkgs.coreutils}/bin/printf "%s\n" \
          "monitorv2 {" \
          "	output = HDMI-A-1" \
          "	mode = 1920x1080@60" \
          "	position = 0x0" \
          "	scale = 1" \
          "	transform = 0" \
          "	vrr = 0" \
          "	cm = srgb" \
          "	supports_wide_color = 0" \
          "	supports_hdr = 0" \
          "	bitdepth = 8" \
          "}" \
          "" \
          "monitor = DP-1, disable" \
          "monitor = DP-2, disable" \
          "monitor = DP-3, disable" \
          > "$tmpfile"

        mv -f "$tmpfile" ~/.config/hypr/displays.conf

        sleep 1 && ${pkgs.hyprland}/bin/hyprctl reload
        sleep 3 && ${pkgs.systemd}/bin/systemctl --user restart sunshine

        exit 0          
      fi

      ${pkgs.systemd}/bin/systemctl --user set-environment REMOTE_ENABLED=0

      # Restore desktop config if not remote
      if [[ -f "$display_cfg".gsc ]]; then
        mv -f "$display_cfg".gsc "$display_cfg"
      fi
      ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 1 silent] firefox"
      ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 4 silent] steam"
      sleep 1 && ${pkgs.hyprland}/bin/hyprctl dispatch exec "[workspace 2 silent] discord"
    '';
    # Bodge to work around gamescope cursor grab not working on games with launchers
    gamescope-cursor-fix = pkgs.writeShellScript "gamescope-cursor-fix.sh" ''
      SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      
      ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do
        if [[ "$line" =~ ^openwindow.*gamescope ]] || [[ "$line" =~ ^openwindow.*gamescope-wrapped ]]; then
          # wait a moment to ensure window is mapped
          sleep 0.1
          
          # Toggle focus
          # Causes fullscreen exit -- needs reapply

          pre_fullscreen=$(hyprctl -j clients \
            | ${pkgs.jq}/bin/jq '.[] | select(.focusHistoryID == 0) | .fullscreen')
          
          hyprctl dispatch focuscurrentorlast; hyprctl dispatch focuscurrentorlast

          post_fullscreen=$(hyprctl -j clients \
            | ${pkgs.jq}/bin/jq '.[] | select(.focusHistoryID == 0) | .fullscreen')

          if [[ "$pre_fullscreen" -gt 0 && "$post_fullscreen" -eq 0 ]]; then
            hyprctl dispatch fullscreen
          fi

        fi
      done
    '';
  in {
    enable = true;
    systemd.enable = true;
    # Tempotary config when using overlayed patched Hyprland alongside flake
    package = null;
    #package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    #importantPrefixes = [ "output" ];
    settings = {
      "$mainMod" = "SUPER";
      # Kanshi handles non-HDR stuff
      source = "~/.config/hypr/displays.conf";

      "$terminal" = "alacritty";
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
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "_JAVA_AWT_WM_NONREPARENTING,1"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_DBUS_REMOTE,1"
        "NIXOS_OZONE_WL,1"
        "XDG_MENU_PREFIX,plasma-"
      ];

      #plugin = {
        #hy3 = {
        #  autotile.enable = true;
        #};
      #};

      general = {
        gaps_in = 2;
        gaps_out = 4;
        border_size = 2;
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
          size = 2;
          passes = 1;
          vibrancy = 0.1696;
          vibrancy_darkness = 1.0;
          contrast = 2.0;
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
          "workspaces, 1, 0.94, almostLinear, fade"
          "workspacesIn, 0, 1.21, almostLinear, fade"
          "workspacesOut, 1, 0.94, almostLinear, fade"
        ];
      };

      workspace = [
        "w[tv1], gapsout:0, gapsin:0"
        "f[1], gapsout:0, gapsin:0"
        "1,monitor:DP-1"
        "2,monitor:DP-2"
        "4,monitor:DP-1"
      ];

      windowrule = [
        "match:workspace w[tv1], match:float 0, border_size 0, rounding 0"
        "match:workspace f[1], match:float 0, border_size 0, rounding 0"
        "match:class .*, suppress_event maximize"
        "match:class ^(xwaylandvideobridge)$, opacity 0.0 override, no_anim 1, no_initial_focus 1, max_size 1 1, no_blur 1, no_focus 1"
        # Fix some dragging issues with XWayland ?
        #"match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0, no_focus 1"
        "match:class ^(com.moonlight_stream.Moonlight)$, content game"
        "match:class ^gamescope$, content game"
        "match:class ^.gamescope-wrapped$, content game"
        "match:class ^(steam_app_\\d+)$, content game" # All Steam apps are considered games
        # Help deal with gamescope input going through to Steam
        "match:class ^(steam)$, no_initial_focus 1, no_blur 1"
        "match:class ^(steam)$, match:title ^$, match:float 1, no_blur 1, no_anim 1"
        "match:title ^(Steam Big Picture Mode)$, fullscreen 1"
        "match:class ^(steam)$, match:title negative:^(Steam)$, float 1"

        "match:class ^(vesktop)$, workspace 2 silent"
        "match:class ^(discord)$, workspace 2 silent"
        "match:class ^(steam)$, workspace 4 silent"

        "match:class ^()$ match:title ^()$ no_blur"
      ];

      layerrule = [
        # Don't clobber slurp's overlay window
        "match:namespace selection, no_anim 1"
        # https://github.com/ErikReider/SwayNotificationCenter/issues/424#issuecomment-2694101051
        "match:namespace swaync-notification-window, blur 1, ignore_alpha 0.5"
        "match:namespace swaync-control-center, blur 1, ignore_alpha 0.5"
        "match:namespace rofi, blur 1, ignore_alpha 0.5"
        "match:namespace waybar, blur 1, ignore_alpha 0.5"
      ];

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2; # Split to right, down
        split_width_multiplier = 1.3; # Work around autotiling preferring vertical splits somewhat often
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
        direct_scanout = 2;
        cm_fs_passthrough = 2;
        cm_auto_hdr = 1;
        cm_sdr_eotf = 2;
        non_shader_cm = 2;
      };

      debug = {
        # Required for FFXVI to not crash with xx_color_management_v4 = true
        # Required for Auto HDR to work with gamescope with xx_color_management_v4 = false
        full_cm_proto = true;
      };

      quirks = {
        prefer_hdr = 2;
        skip_non_kms_dmabuf_formats = true;
      };

      ### INPUT ###

      input = {
        kb_layout = "us";
        #kb_variant = "";
        #kb_model = "";
        #kb_options = "";
        #kb_rules = "";
        follow_mouse = 1;
        accel_profile = "flat";
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
        no_break_fs_vrr = 2; # 0 ironically works better for mouselook games, but requires HW cursor not to spike FPS
        no_hardware_cursors = 0;
        min_refresh_rate = 80; # 48 is technically OK, but causes stutters (even when set to 72)
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
        "CTRL, Print, exec, ${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service && ${pkgs.libnotify}/bin/notify-send -a 'gpu-screen-recorder' 'Saving replay...'"
        "CTRL SHIFT, Next, exec, ${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service && ${pkgs.libnotify}/bin/notify-send -a 'gpu-screen-recorder' 'Saving replay...'" # Page Down

        # Start / stop manual recording if gpu-screen-recorder -ro is running
        "CTRL SHIFT, Print, exec, ${checkrec}"
        "CTRL SHIFT, Prior, exec, ${checkrec}" # Page Up

        "CTRL SHIFT, B, exec, hypr-toggle-hdr"
      ];

      bindo = let
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



      ### AUTOSTART ###
      exec-once = [
        "${pkgs.systemd}/bin/systemctl --user stop plasma-xdg-desktop-portal-kde"
        "${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal"
        "${pkgs.systemd}/bin/exec systemctl --user import-environment PATH" # Useful for Sunshine scripts
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
        "${pkgs.legacy.kdePackages.xwaylandvideobridge}/bin/xwaylandvideobridge"
        "ls \"$XDG_RUNTIME_DIR/dri\" 2> /dev/null | ${pkgs.gnugrep}/bin/grep -q dgpu && sleep 2 && systemctl --user restart gpu-screen-recorder"
      ];
      exec = [
        "kill `pgrep hyprpaper`; sleep 1 && ${pkgs.hyprpaper}/bin/hyprpaper &"
        #"timeout 10 kanshi &"
        # Waybar freezes on reload on Hyprland sometimes, so just restart
        "kill `pgrep waybar`; sleep 1 && waybar &"
        "sleep 1; systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder"
      ];
    };

    extraConfig = ''
      debug:disable_scale_checks = true
      ## Resize mode/submap
      bind=$mainMod,R,submap,resize
      submap=resize
          unbind = ,down
          #binde = , right, resizeactive,  100 0
          #binde = , left,  resizeactive, -100 0
          #binde = , down,  resizeactive,  0 100
          #binde = , up,    resizeactive,  0 -100
          binde = , right, exec, hyprctl --batch "keyword misc:animate_manual_resizes true ; dispatch resizeactive 100 0 ; keyword misc:animate_manual_resizes false"
          binde = , left,  exec, hyprctl --batch "keyword misc:animate_manual_resizes true ; dispatch resizeactive -100 0 ; keyword misc:animate_manual_resizes false"
          binde = , down,  exec, hyprctl --batch "keyword misc:animate_manual_resizes true ; dispatch resizeactive 0 100 ; keyword misc:animate_manual_resizes false"
          binde = , up,    exec, hyprctl --batch "keyword misc:animate_manual_resizes true ; dispatch resizeactive 0 -100 ; keyword misc:animate_manual_resizes false"
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

              hyprctl --batch "keyword monitorv2[$monitor]:cm hdr ; keyword monitorv2[$monitor]:bitdepth 10"
              ;;
            off)
              if [ "$current_mode" = "srgb" ]; then
                echo "Already in sRGB mode; nothing to do."
                exit 0
              fi
              echo "Disabling HDR"
              hyprctl keyword "monitorv2[$monitor]:cm" srgb
              ;;
            *)
              if [ "$current_mode" = "hdr" ]; then
                echo "Toggling: disabling HDR"
                hyprctl keyword "monitorv2[$monitor]:cm" srgb
              else
                echo "Toggling: enabling HDR"
                hyprctl keyword "monitorv2[$monitor]:cm" hdr
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
