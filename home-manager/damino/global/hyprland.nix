{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ./wlogout.nix
    ./waybar.nix
    ./rofi.nix
  ];

  wayland.windowManager.hyprland =
  let
    toggle-hdr = pkgs.writeShellScript "toggle-hdr.sh" ''
      #!/usr/bin/env bash

      conf="$HOME/.config/hypr/displays.conf"

      mon_id=$(${pkgs.hyprland}/bin/hyprctl activewindow -j | jq -r '.monitor')
      monitor=$(${pkgs.hyprland}/bin/hyprctl monitors -j | jq -r ".[] | select(.id == $mon_id) | .name")

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
        echo "HDR support detected on $monitor, toggling cm..."
        has_srgb=$(${pkgs.gawk}/bin/awk -v mon="$monitor" '
          BEGIN { inblock=0; has_output=0; has_srgb=0 }
          /^[[:space:]]*monitorv2[[:space:]]*\{/ { inblock=1; has_output=0; has_srgb=0; next }
          /^[[:space:]]*\}/ { 
            if (inblock && has_output && has_srgb) { print "yes"; exit } 
            inblock=0 
          }
          inblock {
            if ($0 ~ ("output = " mon)) has_output=1
            if ($0 ~ /cm = srgb/) has_srgb=1
          }
          ' "$conf")

          if [ "$has_srgb" = "yes" ]; then
            echo "Enabling HDR"
            ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
              /output = $monitor/,/}/s/cm = srgb/cm = hdr/
            }" "$conf"
          else
            echo "Disabling HDR"
            ${pkgs.gnused}/bin/sed -i "/monitorv2 {/,/}/{
              /output = $monitor/,/}/s/cm = hdr/cm = srgb/
            }" "$conf"
        fi

        #${pkgs.hyprland}/bin/hyprctl reload
      else
        echo "HDR not supported on $monitor; no changes made."
      fi
    '';
  in {
    enable = true;
    systemd.enable = true;
    #importantPrefixes = [ "output" ];
    plugins = [ pkgs.hyprlandPlugins.hy3 ];
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
        "AQ_DRM_DEVICES,/dev/dri/card0"
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

      plugin = {
        hy3 = {
          autotile.enable = true;
        };
      };

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
        #layout = dwindle
        layout = "hy3";
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
          enabled = false;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      "windowrulev2" = "noblur,class:^()$,title:^()$";

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
        # Fix some dragging issues with XWayland
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1; # Disable anime mascot wallpapers
        disable_hyprland_logo = true; # If true disables the random hyprland logo / anime girl background
        enable_anr_dialog = false; # Disable "not responding" popups
        vrr = 2;
      };

      render = {
        direct_scanout = 1;
        cm_fs_passthrough = 0;
        cm_auto_hdr = 0;
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

      gestures = {
        workspace_swipe = false;
      };

      cursor = {
        no_warps = true;
        no_break_fs_vrr = 1;
      };

      ### KEYBINDINGS ###
      bind = [
        "$mainMod, Return, exec, $terminal"
        "$mainMod SHIFT, Q, killactive,"
        "$mainMod SHIFT, E, exit,"
        "$mainMod SHIFT, Space, togglefloating,"
        "$mainMod, D, exec, $menu"
        # $mainMod, H, togglesplit, # dwindle
        "$mainMod, F, fullscreen"
        "$mainMod, left, hy3:movefocus, l"
        "$mainMod, right, hy3:movefocus, r"
        "$mainMod, up, hy3:movefocus, u"
        "$mainMod, down, hy3:movefocus, d"
        # $mainMod, left, movefocus, l
        # $mainMod, right, movefocus, r
        # $mainMod, up, movefocus, u
        # $mainMod, down, movefocus, d
        "$mainMod, H, hy3:makegroup, h"
        "$mainMod, V, hy3:makegroup, v"
        # $mainMod, space, exec, $(hyprctl activewindow -j | jq '.floating') && hyprctl dispatch cyclenext tiled || hyprctl dispatch cyclenext floating
        "$mainMod, space, hy3:togglefocuslayer, nowarp"

        # Move the active window (use SHIFT as the extra modifier)
        "$mainMod SHIFT, left,  hy3:movewindow, l"
        "$mainMod SHIFT, right, hy3:movewindow, r"
        "$mainMod SHIFT, up,    hy3:movewindow, u"
        "$mainMod SHIFT, down,  hy3:movewindow, d"
        #"$mainMod SHIFT, left,  movewindow, l"
        #"$mainMod SHIFT, right, movewindow, r"
        #"$mainMod SHIFT, up,    movewindow, u"
        #"$mainMod SHIFT, down,  movewindow, d"

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
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Notification daemon
        "CTRL, SPACE, exec, swaync-client --hide-latest"
        "CTRL, grave, exec, swaync-client --toggle-panel"

        "CTRL SHIFT, B, exec, ${toggle-hdr}"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      bindl = [
        ",XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%"
        # ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        ",XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%"
        # ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ",XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle"
        # ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ",XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SINK@ toggle"
        # ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      experimental = {
        xx_color_management_v4 = true;
      };

      ### AUTOSTART ###
      exec-once = [
        "nm-applet &"
        "hyprpaper & firefox"
        # Work around cursor config option unreliability
        "hyprctl setcursor $cursorTheme 24"
        "swaync &"
      ];
      exec = [
        #"timeout 10 kanshi &"
        # Waybar freezes on reload on Hyprland sometimes, so just restart
        "kill `pgrep waybar`; waybar &"
      ];
    };

    extraConfig = ''
      plugin = ${pkgs.hyprlandPlugins.hy3}/lib/libhy3.so
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
    swaync = {
      enable = true;
      settings = {
        timeout = 4;
        notification-window-preferred-output = "DP-2";
        notification-window-width = 350;
      };
      style = ''
        window {
            font-family: Inter;
            font-size: 11px;
        }
        
        .notification {
            background: #${config.colorScheme.palette.base00};
            border: 2px solid #${config.colorScheme.palette.base0D};
            border-radius: 6px;
            color: #${config.colorScheme.palette.base05};
        }
        
        .notification.low {
            color: #${config.colorScheme.palette.base0A};
        }
        
        .notification.high {
            border-color: #${config.colorScheme.palette.base08};
        }
        
        .progressbar {
            background-color: transparent;
            color: #${config.colorScheme.palette.base0D};
        }
        
        .image {
            max-width: 16px;
            max-height: 16px;
        }
      '';
    };
  };

  home = {
    file = {
      ".config/hypr/hm/displays.conf" = lib.mkDefault {
        text = ''
          # Default monitor configuration
          monitor=,preferred,auto,auto
          exec = timeout 10 kanshi &
        '';
      };
    };
    packages = with pkgs; [
      hyprpaper
      hyprlandPlugins.hy3
      #edid-decode
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
