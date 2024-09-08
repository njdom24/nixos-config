{ inputs, lib, config, ... }: {
	wayland.windowManager.sway = {
		enable = true;
		systemd.enable = true;
		checkConfig = false;
		extraConfigEarly = ''
		  set $map-to-active swaymsg input type:tablet_tool map_to_output `swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .name'`
		  exec $map-to-active
		  # Super
		  set $mod Mod4
		  # Alt
		  #set $mod Mod1
		  set $ws1 "1"
		  set $ws2 "2"
		  set $ws3 "3"
		  set $ws4 "4"
		  set $ws5 "5"
		  set $ws6 "6"
		  set $ws7 "7"
		  set $ws8 "8"
		  set $ws9 "9"
		  set $ws10 "10"

		  bindsym --locked XF86MonBrightnessUp exec light -A 4
		  bindsym --locked XF86MonBrightnessDown exec light -U 4
		'';
		extraConfig = ''
		  exec systemctl --user restart xdg-desktop-portal
		  exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

		  # TODO: https://github.com/Misterio77/nix-colors
		  # Start flavours
		  ## Base16 Mocha
		  # Author: Chris Kempson (http://chriskempson.com)
		  
		  set $base00 #3b3228
		  set $base01 #534636
		  set $base02 #645240
		  set $base03 #7e705a
		  set $base04 #b8afad
		  set $base05 #d0c8c6
		  set $base06 #e9e1dd
		  set $base07 #f5eeeb
		  set $base08 #cb6077
		  set $base09 #d28b71
		  set $base0A #f4bc87
		  set $base0B #beb55b
		  set $base0C #7bbda4
		  set $base0D #8ab3b5
		  set $base0E #a89bb9
		  set $base0F #bb9584
		  # End flavours
		  client.focused          $base05 $base04 $base00 $base04 $base04
		  client.focused_inactive $base01 $base01 $base05 $base03 $base01
		  client.unfocused        $base01 $base00 $base05 $base01 $base01
		  client.urgent           $base08 $base08 $base00 $base08 $base08
		  client.placeholder      $base00 $base00 $base05 $base00 $base00
		  client.background       $base07

		  exec_always timeout 10 kanshi
		  exec mako
		  exec QT_QPA_PLATFORMTHEME= corectrl
		  exec gtk-launch firefox.desktop
		  exec gtk-launch vesktop.desktop
		  exec gtk-launch steam.desktop
		'';

		config = {
		  #modifier = "Mod4";
		  window = {
		    commands  = [
		  	  {
		        command = "move scratchpad";
		    	criteria = { instance = "scratchpad"; };
		      }
		      {
		      	command = "border pixel 1";
		      	criteria = { class = "^.*"; };
		      }
		    ];
		  };
		  bars = [{
		  	command = "waybar";
		  	position = "top";
		  }];
		  output = {
		  	"*" = {
		  	  bg = "${config.home.homeDirectory}/Pictures/Wallpapers/New Gridania.jpeg fill";	
		  	};
		  };
		  input = {
		  	"type:pointer" = { accel_profile = "flat"; };
		  	"type:touchpad" = {
		  		tap = "enabled";
		  		natural_scroll = "enabled";
		  	};
		  };
		  focus.mouseWarping = false;
		  seat = {
		  	"*" = {
		  	  hide_cursor = "6000";
		  	  xcursor_theme = "${config.gtk.cursorTheme.name}";
		  	};
		  	
		  };
		  gaps = {
		  	smartGaps = true;
		  	smartBorders = "on";
		  	inner = 6;
		  	outer = 0;
		  };
		  keybindings = {
		  	"XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%";
		  	"XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%";
		  	"XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle";
		  	"XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SINK@ toggle";
		  	"Control+grave" = "exec makoctl restore";
		  	"Control+space" = "exec makoctl dismiss";
		  	"$mod+Return" = "exec kitty";
		  	"$mod+Shift+q" = "kill";
		  	"$mod+d" = "exec \"rofi -modi 'drun,run' -theme ${config.xdg.dataHome}/rofi/themes/custom.rasi -show drun\"";
			"$mod+h" = "split h";
			"$mod+v" = "split v";
			"$mod+f" = "fullscreen toggle";
			"$mod+s" = "layout stacking";
			"$mod+w" = "layout tabbed";
			"$mod+e" = "layout toggle split";
			"$mod+Shift+space" = "floating toggle";
			"$mod+space" = "focus mode_toggle";
			"$mod+a" = "focus parent";

			" $mod+1" = "workspace number $ws1 ; exec $map-to-active";
			" $mod+2" = "workspace number $ws2 ; exec $map-to-active";
			" $mod+3" = "workspace number $ws3 ; exec $map-to-active";
			" $mod+4" = "workspace number $ws4 ; exec $map-to-active";
			" $mod+5" = "workspace number $ws5 ; exec $map-to-active";
			" $mod+6" = "workspace number $ws6 ; exec $map-to-active";
			" $mod+7" = "workspace number $ws7 ; exec $map-to-active";
			" $mod+8" = "workspace number $ws8 ; exec $map-to-active";
			" $mod+9" = "workspace number $ws9 ; exec $map-to-active";
			"$mod+0" = "workspace number $ws10 ; exec $map-to-active";

			"$mod+Shift+1" = "move container to workspace number $ws1";
			"$mod+Shift+2" = "move container to workspace number $ws2";
			"$mod+Shift+3" = "move container to workspace number $ws3";
			"$mod+Shift+4" = "move container to workspace number $ws4";
			"$mod+Shift+5" = "move container to workspace number $ws5";
			"$mod+Shift+6" = "move container to workspace number $ws6";
			"$mod+Shift+7" = "move container to workspace number $ws7";
			"$mod+Shift+8" = "move container to workspace number $ws8";
			"$mod+Shift+9" = "move container to workspace number $ws9";
			"$mod+Shift+0" = "move container to workspace number $ws10";

			"$mod+Shift+Left" = "move left";
			"$mod+Shift+Right" = "move right";
			"$mod+Shift+Up" = "move up";
			"$mod+Shift+Down" = "move down";
			
			"$mod+Left" = "focus left";
			"$mod+Right" = "focus right";
			"$mod+Up" = "focus up";
			"$mod+Down" = "focus down";

			"$mod+Shift+c" = "reload";
			"$mod+Shift+r" = "restart";
			"$mod+Shift+e" = "exec wlogout -p layer-shell";
			"$mod+r" = "mode \"resize\"";

			"Shift+Print" = "exec 'grim -g \"$(slurp -d)\" - | wl-copy -t image/png'";
			"Shift+Prior" = "exec 'grim -g \"$(slurp -d)\" - | wl-copy -t image/png'";
			"Print" = "exec grim -o \"$(swaymsg -t get_tree | jq -r '.nodes[] | select([recurse(.nodes[]?, .floating_nodes[]?) | .focused] | any) | .name')\" - | wl-copy -t image/png";
			"Shift+Next" = "exec grim -o \"$(swaymsg -t get_tree | jq -r '.nodes[] | select([recurse(.nodes[]?, .floating_nodes[]?) | .focused] | any) | .name')\" - | wl-copy -t image/png";
		  };
		  left = "$mod+Left";
		  right = "$mod+Right";
		  up = "$mod+Up";
		  down = "$mod+Down";
		  floating.modifier = "$mod normal";

		  modes = {
		  	resize = {
		  	  Left = "resize shrink width 10px or 10 ppt";
		  	  Right = "resize grow width 10px or 10 ppt";
		  	  Up = "resize shrink height 10px or 10 ppt";
		  	  Down = "resize grow height 10px or 10 ppt";

		  	  Return = "mode \"default\"";
		  	  Escape = "mode \"default\"";
		  	  "$mod+r" = "mode \"default\"";

		  	  "$mod+w" = "output HDMI-A-1 enable mode 2560x1440@120Hz pos 0 0; output DP-1 disable; output DP-2 disable; output * adaptive_sync on; exec pactl set-default-sinkalsa_output.pci-0000_0f_00.1.pro-output-3";
			  "$mod+o" = "exec timeout 10 kanshi";
		  	};
		  };

		  assigns = {
		  	"4" = [{ instance="steamwebhelper"; }];
		  };
		};

	    extraSessionCommands = ''
		  #export SDL_VIDEODRIVER=wayland
		  export QT_QPA_PLATFORM="wayland;xcb"
		  export GDK_BACKEND=wayland,x11
		  export CLUTTER_BACKEND=wayland
		  export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
		  export _JAVA_AWT_WM_NONREPARENTING=1
		  export MOZ_ENABLE_WAYLAND=1
		  export MOZ_DBUS_REMOTE=1
		  export XDG_CURRENT_DESKTOP=sway
		  export NIXOS_OZONE_WL=1

		  export REMOTE_ENABLED=$(pgrep -x x11vnc > /dev/null && echo 1 || echo 0)
		  export WLR_NO_HARDWARE_CURSORS="''${WLR_NO_HARDWARE_CURSORS:-$REMOTE_ENABLED}"
		  export WLR_BACKENDS=$([ $REMOTE_ENABLED = 1 ] && echo "headless,libinput" || echo "drm,libinput")
		    
		  eval $(gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)
		  export SSH_AUTH_SOCK
	    '';
	};

	# """ # Workaround to fix highlighting

	services = {
	  kanshi = {
	    enable = true;
	    #Install.WantedBy = lib.mkForce [ ];
	    systemdTarget = "";
	  };
	};
}
