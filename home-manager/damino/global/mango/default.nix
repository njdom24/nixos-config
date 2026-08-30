{ inputs, lib, config, pkgs, ... }: {
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
          #env=DISPLAY,:1
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
          env=WLR_DRM_DEVICES,/run/user/1000/dri/dgpu0
          env=WLR_RENDER_DRM_DEVICE,/run/user/1000/dri/dgpu0-render
          
          # Use xwayland-satellite instead
          xwayland_persistence=0
          exec-once=xwayland-satellite
          exec=bash -c "sleep 2 && noctalia"
          exec-once=kanshi
          exec-once=dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
          exec-once=systemctl --user start mango-session.target
          exec-once=systemctl --user restart xdg-desktop-portal
          exec-once=systemctl --user restart xdg-desktop-portal-hyprland
          exec-once=rm -f ~/.config/mango/monitors.conf.bak
          exec-once=bash -c "sleep 2 && mmsg dispatch togglehdr,on,DP-1 && ~/.config/mango/mango-snapshot-outputs.sh"
          exec-once=bash -c "sleep 3 && wlr-hdr-cal"
          exec-once=bash -c "rm ~/.config/mango/monitors.conf && mmsg dispatch reload_config && kanshi"
          exec-once=~/.config/mango/mango-fullscreen-vrr.sh DP-1 HDMI-A-1
          exec=~/.config/mango/mango-workspace.sh assign 1 DP-1
          exec=~/.config/mango/mango-workspace.sh assign 4 DP-1
          exec=~/.config/mango/mango-workspace.sh assign 2 DP-2
          exec-once=~/.config/mango/mango-spawn-on-tag.sh 1 DP-1 firefox firefox
          exec-once=~/.config/mango/mango-spawn-on-tag.sh 2 DP-2 discord env DISPLAY=:1 discord
          exec-once=~/.config/mango/mango-spawn-on-tag.sh 4 DP-1 steam env DISPLAY=:1 gtk-launch steam.desktop
          #exec-once=discord
          #exec-once=gtk-launch steam.desktop
          
          circle_layout=dwindle
          
          # Monitor rules
          #monitorrule=name:.+,vrr:0
          #windowrule=title:.+,vrr_only_fullscreen:1
          
          #monitorrule=name:^DP-1$,hdr:0
          #monitorrule=name:^DP-1$,width:2560,height:1440,refresh:180,x:2560,y:0,hdr:1
          
          windowrule=appid:discord,isopensilent:1
          windowrule=appid:steam,isopensilent:1,force_tiled_state:1
          
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
          #shadowscolor= 0x000000ff
          
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
          fadein_begin_opacity=0.5
          fadeout_begin_opacity=0.8
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
          animation_curve_opafadeout=0.5,0.5,0.5,0.5
          animation_curve_opafadein=0.46,1.0,0.29,1
          
          # Dwindle Layout Setting
          dwindle_smart_split=0
          dwindle_smart_resize=0
          dwindle_drop_simple_split=1
          dwindle_split_ratio=0.5
          dwindle_manual_split=0
          dwindle_hsplit=1
          dwindle_vsplit=1
          dwindle_preserve_split=1
          
          # Overview Setting
          hotarea_size=10
          enable_hotarea=0
          ov_tab_mode=1
          ov_no_resize=1
          overviewgappi=5
          overviewgappo=30
          
          # Misc
          no_border_when_single=1
          axis_bind_apply_timeout=100
          focus_on_activate=0
          idleinhibit_ignore_visible=0
          sloppyfocus=1
          warpcursor=1
          focus_cross_monitor=1
          focus_cross_tag=1
          
          # Handled by script to send instead of exchanging
          exchange_cross_monitor=0
          
          enable_floating_snap=0
          snap_distance=30
          cursor_size=25
          cursor_hide_timeout=10
          drag_tile_to_tile=1
          drag_tile_small=1
          syncobj_enable=1
          smartgaps=1
          
          # keyboard
          repeat_rate=25
          repeat_delay=600
          numlockon=0
          xkb_rules_layout=us
          
          # Trackpad
          # need relogin to make it apply
          disable_trackpad=0
          tap_to_click=1
          tap_and_drag=1
          drag_lock=1
          trackpad_natural_scrolling=0
          disable_while_typing=1
          left_handed=0
          middle_button_emulation=0
          swipe_min_threshold=1
          
          # mouse
          # need relogin to make it apply
          mouse_natural_scrolling=0
          mouse_accel_profile=0
          
          # Appearance
          gappih=4
          gappiv=4
          gappoh=4
          gappov=4
          scratchpad_width_ratio=0.8
          scratchpad_height_ratio=0.9
          borderpx=2
          #shadowscolor= 0x${config.lib.stylix.colors.base00}ff
          rootcolor=0x${config.lib.stylix.colors.base00}ff
          bordercolor=0x${config.lib.stylix.colors.base01}ff
          dropcolor=0x${config.lib.stylix.colors.base0C}55
          splitcolor=0x${config.lib.stylix.colors.base05}ff
          focuscolor=0x${config.lib.stylix.colors.base04}ff
          maximizescreencolor=0x${config.lib.stylix.colors.base0B}ff
          urgentcolor=0x${config.lib.stylix.colors.base0F}ff
          scratchpadcolor=0x${config.lib.stylix.colors.base03}ff
          globalcolor=0x${config.lib.stylix.colors.base08}ff
          overlaycolor=0x${config.lib.stylix.colors.base0C}ff
          
          # layout support:
          # tile,scroller,grid,deck,monocle,center_tile,vertical_tile,vertical_scroller
          tagrule=id:1,layout_name:dwindle
          tagrule=id:2,layout_name:dwindle
          tagrule=id:3,layout_name:dwindle
          tagrule=id:4,layout_name:dwindle
          tagrule=id:5,layout_name:dwindle
          tagrule=id:6,layout_name:dwindle
          tagrule=id:7,layout_name:dwindle
          tagrule=id:8,layout_name:dwindle
          tagrule=id:9,layout_name:dwindle
          
          # Key Bindings
          # key name refer to `xev` or `wev` command output,
          # mod keys name: super,ctrl,alt,shift,none
          
          # Default mode bindings
          keymode=default
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
          #bind=SUPER+SHIFT,Up,exchange_client,up
          #bind=SUPER+SHIFT,Down,exchange_client,down
          #bind=SUPER+SHIFT,Left,exchange_client,left
          #bind=SUPER+SHIFT,Right,exchange_client,right
          
          #bind=SUPER+SHIFT,Up,spawn,~/.config/mango/mango-exchange-or-move.sh up
          #bind=SUPER+SHIFT,Down,spawn,~/.config/mango/mango-exchange-or-move.sh down
          #bind=SUPER+SHIFT,Left,spawn,~/.config/mango/mango-exchange-or-move.sh left
          #bind=SUPER+SHIFT,Right,spawn,~/.config/mango/mango-exchange-or-move.sh right

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
          #bind=SUPER,v,dwindle_split_vertical
          #bind=SUPER,h,dwindle_split_horizontal
          bind=SUPER,v,dwindle_toggle_current_split
          bind=SUPER,h,dwindle_toggle_current_split
          
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
          keymode=resize
          bind=NONE,Left,resizewin,-100,+0
          bind=NONE,Right,resizewin,+100,+0
          bind=NONE,UP,resizewin,+0,+100
          bind=NONE,Down,resizewin,+0,-100
          bind=SUPER,R,setkeymode,default
          bind=NONE,Escape,setkeymode,default
          
          source-optional=~/.config/mango/monitors.conf
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
        "mango-workspace.sh"
        "mango-focusdir.sh"
        "mango-exchange-or-move.sh"
        "mango-screenshot.sh"
        "mango-spawn-on-tag.sh"
        "mango-virtual-monitor.sh"
        "mango-snapshot-outputs.sh"
        "mango-floating-focus.sh"
        "mango-fullscreen-vrr.sh"
        "mango-move-float.sh"
      ])
    );
  };
}
