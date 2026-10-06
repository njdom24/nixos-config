{ inputs, lib, config, pkgs, ... }:
let
  mango-satellite-wrapper = pkgs.writeShellScriptBin "mango-satellite-wrapper" ''
    # Subsequent calls probably belong to gamescope
    if [ "$1" != ":0" ]; then
      exec ${pkgs.xwayland}/bin/Xwayland "$@"
    else
      echo "dummy"
    fi
  '';

  mango-satellite-runner = pkgs.writeShellScript "mango-satellite-runner" ''
    MAX_ATTEMPTS=10
    ATTEMPT=0

    while (( ATTEMPT < MAX_ATTEMPTS )); do
        ATTEMPT=$(( ATTEMPT + 1 ))

        ${pkgs.xwayland-satellite}/bin/xwayland-satellite &
        XWS_PID=$!

        # Give it a moment to initialize
        sleep 1

        if ${pkgs.xrandr}/bin/xrandr &>/dev/null; then
          exit 0
        fi

        # Started on wrong display. Kill and retry
        kill "$XWS_PID" 2>/dev/null || true
        wait "$XWS_PID" 2>/dev/null || true
    done
    exit 1
  '';
in {
  imports = [
  ];
  xdg.portal = {
    configPackages = [ pkgs.mango ];
    config.mango = {
      default = [ "wlr" "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "luminous" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  # Trigger graphical-session.target for portal to start
  systemd.user.targets.mango-session = {
    Unit = {
      Description = "Mango compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  home = {
    packages = with pkgs; [
      jq
      wlr-randr
      grim
      slurp
      wl-clipboard
      imagemagick # provides `magick`, used by mango-screenshot.sh
      brightnessctl
    ];

    file = {
      ".config/mango/config.conf" = {
        text = ''
          # More option see https://github.com/DreamMaoMao/mango/wiki/
          env=SSH_AUTH_SOCK,/run/user/1000/gcr/ssh
          env=SSH_ASKPASS,/run/current-system/sw/libexec/seahorse/ssh-askpass
          env=WLR_XWAYLAND,${mango-satellite-wrapper}/bin/mango-satellite-wrapper
          env=XCURSOR_THEME,XCursor-Pro-Dark
          env=XCURSOR_SIZE,25
          env=QT_QPA_PLATFORM,wayland;xcb
          env=GDK_BACKEND,wayland,x11
          env=CLUTTER_BACKEND,wayland
          env=QT_QPA_PLATFORMTHEME,qt6ct
          env=MOZ_DBUS_REMOTE,1
          env=NIXOS_OZONE_WL,1
          env=XDG_MENU_PREFIX,plasma-
          env=WLR_RENDERER,vulkan

          xwayland_persistence=0
          exec_once=${mango-satellite-runner}
          exec=bash -c "sleep 2 && noctalia"
          exec_once=kanshi
          exec_once=~/.config/mango/mango-autotiling.sh
          exec_once=dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
          exec_once=systemctl --user start mango-session.target
          exec_once=systemctl --user restart xdg-desktop-portal
          exec_once=systemctl --user restart xdg-desktop-portal-hyprland
          exec_once=bash -c "kanshi"
          exec_once=bash -c "sleep 2 && mmsg dispatch togglehdr,on,DP-1"
          exec_once=bash -c "sleep 3 && wlr-hdr-cal"
          exec_once=~/.config/mango/mango-fullscreen-vrr.sh DP-1 HDMI-A-1
          exec=~/.config/mango/mango-workspace.sh assign 1 DP-1
          exec=~/.config/mango/mango-workspace.sh assign 4 DP-1
          exec=~/.config/mango/mango-workspace.sh assign 2 DP-2
          exec_once=firefox
          exec_once=discord
          exec_once=bash -c "sleep 1 && gtk-launch steam.desktop"
          exec_once=bash -c "sleep 1 && gsr-ui"
          #exec_once=discord
          #exec_once=gtk-launch steam.desktop

          window_rule_once=tags:1,monitor:DP-1,app_id:firefox
          window_rule=tags:4,monitor:DP-1,app_id:steam
          window_rule=tags:2,monitor:DP-2,app_id:discord
          
          circle_layout=dwindle
          
          # Monitor rules
          #monitor_rule=name:.+,vrr:0
          #window_rule=title:.+,vrr_only_fullscreen:1
          
          #monitor_rule=name:^DP-1$,hdr:0
          #monitor_rule=name:^DP-1$,width:2560,height:1440,refresh:180,x:2560,y:0,hdr:1
          
          window_rule=app_id:discord,is_open_silent:1
          window_rule=app_id:steam,is_open_silent:1,force_tiled_state:1

          window_rule=is_fullscreen:1,app_id:gamescope
          window_rule=is_fullscreen:1,app_id:^(steam_app_\d+)$

          window_rule=app_id:gsr-ui,is_floating:1,is_fullscreen:1
          
          # Window effect
          #blur=0
          #blur_layer=0
          #blur_optimized=1
          #blur_params_num_passes = 2
          #blur_params_radius = 5
          #blur_params_noise = 0.02
          #blur_params_brightness = 0.9
          #blur_params_contrast = 0.9
          #blur_params_saturation = 1.2
          
          #shadows = 0
          #layer_shadows = 0
          #shadow_only_floating = 1
          #shadows_size = 10
          #shadows_blur = 15
          #shadows_position_x = 0
          #shadows_position_y = 0
          #shadows_color= 0x000000ff
          
          #border_radius=0
          #no_radius_when_single=0
          
          focused_opacity=1.0
          unfocused_opacity=1.0
          
          # Animation Configuration(support type:zoom,slide)
          # tag_animation_direction: 1-horizontal,0-vertical
          animations=1
          layer_animations=1
          animation_type_open=zoom
          animation_type_close=zoom
          animation_fade_in=1
          animation_fade_out=1
          tag_animation_direction=0
          zoom_initial_ratio=0.4
          zoom_end_ratio=0.8
          fade_in_begin_opacity=0.5
          fade_out_begin_opacity=0.8
          animation_duration_move=250
          animation_duration_open=200
          animation_duration_tag=175
          animation_duration_close=200
          animation_duration_focus=0
          animation_curve_open=0.46,1.0,0.29,1
          animation_curve_move=0.46,1.0,0.29,1
          animation_curve_tag=0.46,1.0,0.29,1
          animation_curve_close=0.08,0.92,0,1
          animation_curve_focus=0.46,1.0,0.29,1
          animation_curve_opacity_fade_out=0.5,0.5,0.5,0.5
          animation_curve_opacity_fade_in=0.46,1.0,0.29,1
          
          # Dwindle Layout Setting
          dwindle_smart_split=0
          dwindle_smart_resize=0
          dwindle_drop_simple_split=1
          dwindle_split_ratio=0.5
          dwindle_manual_split=1
          dwindle_horizontal_split=1
          dwindle_vertical_split=1
          dwindle_preserve_split=1
          
          # Overview Setting
          hotarea_size=10
          enable_hotarea=0
          overview_gap_inner=5
          overview_gap_outer=30
          
          # Misc
          no_border_when_single=1
          axis_bind_apply_timeout=100
          focus_on_activate=0
          idle_inhibit_ignore_visible=0
          sloppy_focus=1
          warp_cursor=1
          focus_cross_monitor=1
          focus_cross_tag=1
          
          # Handled by script to send instead of exchanging
          exchange_cross_monitor=1
          
          enable_floating_snap=0
          snap_distance=30
          cursor_size=25
          cursor_hide_timeout=10
          drag_tile_to_tile=1
          drag_tile_small=1
          sync_obj_enable=1
          smart_gaps=1
          
          # keyboard
          repeat_rate=25
          repeat_delay=600
          numlock_on=0
          xkb_rules_layout=us
          
          # Trackpad
          # need relogin to make it apply
          disable_trackpad=0
          tap_to_click=1
          tap_and_drag=1
          drag_lock=1
          trackpad_natural_scrolling=1
          trackpad_disable_while_typing=1
          trackpad_left_handed=0
          trackpad_middle_button_emulation=0
          swipe_min_threshold=1
          
          # mouse
          # need relogin to make it apply
          mouse_natural_scrolling=0
          mouse_accel_profile=0
          
          # Appearance
          gap_inner_horizontal=4
          gap_inner_vertical=4
          gap_outer_horizontal=4
          gap_outer_vertical=4
          scratchpad_width_ratio=0.8
          scratchpad_height_ratio=0.9
          border_px=2
          #shadows_color= 0x${config.lib.stylix.colors.base00}ff
          root_color=0x${config.lib.stylix.colors.base00}ff
          border_color=0x${config.lib.stylix.colors.base01}ff
          drop_color=0x${config.lib.stylix.colors.base0C}55
          split_color=0x${config.lib.stylix.colors.base05}ff
          focus_color=0x${config.lib.stylix.colors.base04}ff
          maximized_screen_color=0x${config.lib.stylix.colors.base0B}ff
          urgent_color=0x${config.lib.stylix.colors.base0F}ff
          scratchpad_color=0x${config.lib.stylix.colors.base03}ff
          global_color=0x${config.lib.stylix.colors.base08}ff
          overlay_color=0x${config.lib.stylix.colors.base0C}ff
          
          # layout support:
          # tile,scroller,grid,deck,monocle,center_tile,vertical_tile,vertical_scroller
          tag_rule=id:1,layout_name:dwindle
          tag_rule=id:2,layout_name:dwindle
          tag_rule=id:3,layout_name:dwindle
          tag_rule=id:4,layout_name:dwindle
          tag_rule=id:5,layout_name:dwindle
          tag_rule=id:6,layout_name:dwindle
          tag_rule=id:7,layout_name:dwindle
          tag_rule=id:8,layout_name:dwindle
          tag_rule=id:9,layout_name:dwindle
          
          # Key Bindings
          # key name refer to `xev` or `wev` command output,
          # mod keys name: super,ctrl,alt,shift,none
          
          # Default mode bindings
          key_mode=default
          bind=SUPER,R,setkeymode,resize
          
          # reload config
          bind=CTRL+SHIFT,r,reload_config
          
          # menu and terminal
          bind=SUPER,d,spawn,noctalia msg panel-toggle launcher
          bind=SUPER,Return,spawn,alacritty
          
          # exit
          bind=SUPER+SHIFT,e,spawn,noctalia msg panel-toggle session
          bind=SUPER+SHIFT,q,killclient,
          
          # switch window focus
          bind=ALT,Tab,focusstack,next
          #bind=SUPER,Left,focusdir,left
          #bind=SUPER,Right,focusdir,right
          #bind=SUPER,Up,focusdir,up
          #bind=SUPER,Down,focusdir,down
          bind=SUPER,Left,spawn,~/.config/mango/mango-focusdir.sh left
          bind=SUPER,Right,spawn,~/.config/mango/mango-focusdir.sh right
          bind=SUPER,Up,spawn,~/.config/mango/mango-focusdir.sh up
          bind=SUPER,Down,spawn,~/.config/mango/mango-focusdir.sh down
          bind=SUPER,Space,spawn,~/.config/mango/mango-floating-focus.sh
          
          # swap window
          #bind=SUPER+SHIFT,Up,move_client,up
          #bind=SUPER+SHIFT,Down,move_client,down
          #bind=SUPER+SHIFT,Left,move_client,left
          #bind=SUPER+SHIFT,Right,move_client,right

          # mango-move-float wraps mango-exchange-or-move for tiled windows
          bind=SUPER+SHIFT,Up,spawn,~/.config/mango/mango-move-float.sh up
          bind=SUPER+SHIFT,Down,spawn,~/.config/mango/mango-move-float.sh down
          bind=SUPER+SHIFT,Left,spawn,~/.config/mango/mango-move-float.sh left
          bind=SUPER+SHIFT,Right,spawn,~/.config/mango/mango-move-float.sh right
          
          # switch window status
          #bind=SUPER,g,toggleglobal,
          bind=SUPER,Tab,toggleoverview,
          bind=SUPER+SHIFT,space,togglefloating,
          #bind=ALT,a,togglemaximizescreen,
          bind=SUPER,f,togglefullscreen,
          bind=SUPER+SHIFT,f,togglefakefullscreen,
          #bind=SUPER,i,minimized,
          #bind=SUPER,o,toggleoverlay,
          #bind=SUPER+SHIFT,I,restore_minimized
          #bind=ALT,z,toggle_scratchpad
          bind=CTRL+SHIFT,B,spawn,mmsg dispatch togglehdr
          
          # scroller layout
          #bind=ALT,e,set_proportion,1.0
          #bind=ALT,x,switch_proportion_preset,
          #bind=alt+super+ctrl,Left,scroller_stack,left
          #bind=alt+super+ctrl,Right,scroller_stack,right
          #bind=alt+super+ctrl,Up,scroller_stack,up
          #bind=alt+super+ctrl,Down,scroller_stack,down
          
          #dwindle layout(manual split mode)
          bind=SUPER,v,dwindle_split_vertical
          bind=SUPER,h,dwindle_split_horizontal
          #bind=SUPER,v,dwindle_toggle_current_split
          #bind=SUPER,h,dwindle_toggle_current_split
          
          # switch layout
          #bind=SUPER,n,switch_layout
          
          # tag switch
          #bind=SUPER,Left,viewtoleft,0
          #bind=CTRL,Left,viewtoleft_have_client,0
          #bind=SUPER,Right,viewtoright,0
          #bind=CTRL,Right,viewtoright_have_client,0
          #bind=CTRL+SUPER,Left,tagtoleft,0
          #bind=CTRL+SUPER,Right,tagtoright,0
          
          #bind=SUPER,1,view,1,0
          #bind=SUPER,2,view,2,0
          #bind=SUPER,3,view,3,0
          #bind=SUPER,4,view,4,0
          #bind=SUPER,5,view,5,0
          #bind=SUPER,6,view,6,0
          #bind=SUPER,7,view,7,0
          #bind=SUPER,8,view,8,0
          #bind=SUPER,9,view,9,0
          #bind=SUPER,0,view,10,0v
          
          bind=SUPER,1,spawn,~/.config/mango/mango-workspace.sh view 1
          bind=SUPER,2,spawn,~/.config/mango/mango-workspace.sh view 2
          bind=SUPER,3,spawn,~/.config/mango/mango-workspace.sh view 3
          bind=SUPER,4,spawn,~/.config/mango/mango-workspace.sh view 4
          bind=SUPER,5,spawn,~/.config/mango/mango-workspace.sh view 5
          bind=SUPER,6,spawn,~/.config/mango/mango-workspace.sh view 6
          bind=SUPER,7,spawn,~/.config/mango/mango-workspace.sh view 7
          bind=SUPER,8,spawn,~/.config/mango/mango-workspace.sh view 8
          bind=SUPER,9,spawn,~/.config/mango/mango-workspace.sh view 9
          
          # tag: move client to the tag and focus it
          # tagsilent: move client to the tag and not focus it
          # bind=Alt,1,tagsilent,1
          #bind=SUPER+SHIFT,1,tagsilent,1
          #bind=SUPER+SHIFT,2,tagsilent,2
          #bind=SUPER+SHIFT,3,tagsilent,3
          #bind=SUPER+SHIFT,4,tagsilent,4
          #bind=SUPER+SHIFT,5,tagsilent,5
          #bind=SUPER+SHIFT,6,tagsilent,6
          #bind=SUPER+SHIFT,7,tagsilent,7
          #bind=SUPER+SHIFT,8,tagsilent,8
          #bind=SUPER+SHIFT,9,tagsilent,9
          #bind=SUPER+SHIFT,0,tagsilent,10
          
          bind=SUPER+SHIFT,1,spawn,~/.config/mango/mango-workspace.sh move 1
          bind=SUPER+SHIFT,2,spawn,~/.config/mango/mango-workspace.sh move 2
          bind=SUPER+SHIFT,3,spawn,~/.config/mango/mango-workspace.sh move 3
          bind=SUPER+SHIFT,4,spawn,~/.config/mango/mango-workspace.sh move 4
          bind=SUPER+SHIFT,5,spawn,~/.config/mango/mango-workspace.sh move 5
          bind=SUPER+SHIFT,6,spawn,~/.config/mango/mango-workspace.sh move 6
          bind=SUPER+SHIFT,7,spawn,~/.config/mango/mango-workspace.sh move 7
          bind=SUPER+SHIFT,8,spawn,~/.config/mango/mango-workspace.sh move 8
          bind=SUPER+SHIFT,9,spawn,~/.config/mango/mango-workspace.sh move 9
          
          # monitor switch
          #bind=alt+shift,Left,focusmon,left
          #bind=alt+shift,Right,focusmon,right
          #bind=SUPER+Alt,Left,tagmon,left
          #bind=SUPER+Alt,Right,tagmon,right
          
          # Notification center
          bind=CTRL,grave,spawn,noctalia msg panel-toggle control-center notifications
          bind=CTRL,space,spawn,noctalia msg notification-clear-active
          
          # gaps
          bind=ALT+SHIFT,X,incgaps,1
          bind=ALT+SHIFT,Z,incgaps,-1
          #bind=ALT+SHIFT,R,togglegaps
          
          # resizewin
          bind=CTRL+ALT,Up,resizewin,+0,-50
          bind=CTRL+ALT,Down,resizewin,+0,+50
          bind=CTRL+ALT,Left,resizewin,-50,+0
          bind=CTRL+ALT,Right,resizewin,+50,+0
          
          # Mouse Button Bindings
          # btn_left and btn_right can't bind none mod key
          mousebind=SUPER,btn_left,moveresize,curmove
          #mousebind=NONE,btn_middle,togglemaximizescreen,0
          mousebind=SUPER,btn_right,moveresize,curresize
          
          # Axis Bindings
          #axisbind=SUPER,UP,viewtoleft_have_client
          #axisbind=SUPER,DOWN,viewtoright_have_client
          
          # ── Screenshots ──────────────────────────────────────────────────────────────
          bind=SHIFT,Print,spawn,~/.config/mango/mango-screenshot.sh select
          bind=NONE,Print,spawn,~/.config/mango/mango-screenshot.sh focused
          # Alternate screenshot aliases (Prior/Next = PgUp/PgDown)
          bind=SHIFT,Prior,spawn,~/.config/mango/mango-screenshot.sh select
          bind=SHIFT,Next,spawn,~/.config/mango/mango-screenshot.sh focused
          
          # Brightness
          bind=NONE,XF86MonBrightnessUp,spawn,brightnessctl s +5%
          bind=NONE,XF86MonBrightnessDown,spawn,brightnessctl s 5%-
          
          # Volume
          bind=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
          bind=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
          bind=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          bind=SHIFT,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
          
          # 'resize' mode bindings
          key_mode=resize
          bind=NONE,Left,resizewin,-100,+0
          bind=NONE,Right,resizewin,+100,+0
          bind=NONE,UP,resizewin,+0,+100
          bind=NONE,Down,resizewin,+0,-100
          bind=SUPER,R,setkeymode,default
          bind=NONE,Escape,setkeymode,default
        '';
      };
    } // (lib.listToAttrs (map
      (name: {
        name = ".config/mango/${name}";
        value = {
          source = ./scripts/${name};
          executable = true;
        };
      })
      [
        "mango-autotiling.sh"
        "mango-workspace.sh"
        "mango-focusdir.sh"
        "mango-screenshot.sh"
        "mango-virtual-monitor.sh"
        "mango-floating-focus.sh"
        "mango-fullscreen-vrr.sh"
        "mango-move-float.sh"
      ])
    );
  };
}
