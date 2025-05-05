{ inputs, lib, config, pkgs, ... }: {
	imports = [
		./wlogout.nix
		./waybar.nix
		./rofi.nix
	];

	wayland.windowManager.sway = {
		enable = true;
		systemd.enable = true;
		checkConfig = false;
		wrapperFeatures.gtk = true;
		extraOptions = [ "--unsupported-gpu" ];
		extraConfigEarly =
		''
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
		  input "1356:3302:Sony_Interactive_Entertainment_DualSense_Wireless_Controller_Touchpad" {
		    events disabled
		  }
		  input "1356:3302:Sunshine_DualSense_(virtual)_pad_Touchpad" {
		    events disabled
		  }
		  input "1356:3302:DualSense_Wireless_Controller_Touchpad" {
		    events disabled
		  }
		'';
		extraConfig = let
		  displaySetup = pkgs.writeShellScript "sway-headless-output.sh" ''
		    #!/bin/bash
		
		    if [ "$REMOTE_ENABLED" = "1" ]; then
		      # Check if any HEADLESS output exists (HEADLESS-1, HEADLESS-2, etc.)
		      existing_headless=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\")) | .name")
		      
		      if [ -z "$existing_headless" ]; then
		        # If no HEADLESS output exists, create one
		        ${pkgs.sway}/bin/swaymsg create_output
		      fi
		      # Disable all non-HEADLESS outputs
		      ${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable
		      ${pkgs.sway}/bin/swaymsg output "*" render_bit_depth 10
		    else
		      # If not remote, run kanshi
		      ${pkgs.coreutils}/bin/timeout 10 ${pkgs.kanshi}/bin/kanshi
		    fi
		  '';

		  # Taken from https://gist.github.com/GrabbenD/adc5a7a863cbd1553461376cf4c50467
		  vrrFullscreen = pkgs.writeShellScript "sway-vrr-fullscreen.sh" ''
		    #!/usr/bin/env bash
		    # List of supported outputs for VRR
		    # TODO: Populate this from NixOS config, and/or convert from display names instead
		    output_vrr_whitelist=(
		      "DP-1"
		      "HDMI-A-1"
		    )
		    
		    # Toggle VRR for fullscreened apps in prespecified displays to avoid stutters while in desktop
		    swaymsg -t subscribe -m '[ "window" ]' | while read window_json; do
		      window_event=$(echo ''\${window_json} | jq -r '.change')

		      # Process only focus change and fullscreen toggle
		      if [[ $window_event = "focus" || $window_event = "fullscreen_mode" ]]; then
		        output_json=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused == true)')
		        output_name=$(echo ''\${output_json} | jq -r '.name')

		        # Use only VRR in whitelisted outputs
		        if [[ ''\${output_vrr_whitelist[*]} =~ ''\${output_name} ]]; then
		          output_vrr_status=$(echo ''\${output_json} | jq -r '.adaptive_sync_status')
		          window_fullscreen_status=$(echo ''\${window_json} | jq -r '.container.fullscreen_mode')

		          # Only update output if nesseccary to avoid flickering
		          [[ $output_vrr_status = "disabled" && $window_fullscreen_status = "1" ]] && swaymsg output "''\${output_name}" adaptive_sync 1
		          [[ $output_vrr_status = "enabled" && $window_fullscreen_status = "0" ]] && swaymsg output "''\${output_name}" adaptive_sync 0
		        fi
		      fi
		    done
		  '';
		in
		''
		  exec systemctl --user restart xdg-desktop-portal
		  exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
		  
		  set $base00 #${config.colorScheme.palette.base00}
		  set $base01 #${config.colorScheme.palette.base01}
		  set $base02 #${config.colorScheme.palette.base02}
		  set $base03 #${config.colorScheme.palette.base03}
		  set $base04 #${config.colorScheme.palette.base04}
		  set $base05 #${config.colorScheme.palette.base05}
		  set $base06 #${config.colorScheme.palette.base06}
		  set $base07 #${config.colorScheme.palette.base07}
		  set $base08 #${config.colorScheme.palette.base08}
		  set $base09 #${config.colorScheme.palette.base09}
		  set $base0A #${config.colorScheme.palette.base0A}
		  set $base0B #${config.colorScheme.palette.base0B}
		  set $base0C #${config.colorScheme.palette.base0C}
		  set $base0D #${config.colorScheme.palette.base0D}
		  set $base0E #${config.colorScheme.palette.base0E}
		  set $base0F #${config.colorScheme.palette.base0F}
		  
		  client.focused          $base05 $base04 $base00 $base04 $base04
		  client.focused_inactive $base01 $base01 $base05 $base03 $base01
		  client.unfocused        $base01 $base00 $base05 $base01 $base01
		  client.urgent           $base08 $base08 $base00 $base08 $base08
		  client.placeholder      $base00 $base00 $base05 $base00 $base00
		  client.background       $base07

          #exec_always timeout 10 kanshi
          exec_always ${displaySetup}
          
		  exec mako
		  exec ${pkgs.networkmanagerapplet}/bin/nm-applet
		  exec_always ${pkgs.autotiling-rs}/bin/autotiling-rs
		  exec ${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs
		  exec ${vrrFullscreen}

		  # exec QT_QPA_PLATFORMTHEME= corectrl
		  exec gtk-launch firefox.desktop
		  exec gtk-launch vesktop.desktop
		  #exec gtk-launch steam.desktop
		  # Temporary until https://gitlab.freedesktop.org/DadSchoorse/mesa/-/commits/radv-float8-hack3
		  exec distrobox enter arch-toolbox-latest -- steam
		  exec ${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --selection-size-limit 1048576 --reconnect-tries 1 --all-mime-type-regex '(?i)^(?!image/x-inkscape-svg).+'
		  exec sh -c 'if [ "$REMOTE_ENABLED" -eq 1 ]; then sleep 5 && systemctl --user start sunshine; fi'
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
		      {
		      	command = "inhibit_idle fullscreen";
		      	criteria = { title = "Steam Big Picture Mode"; };
		      }
		      {
		        command = "move output current ; workspace back_and_forth ; workspace back_and_forth";
		        criteria = { app_id = ".gamescope-wrapped"; };
		      }
		    ];
		  };
		  bars = [{
		  	command = "waybar";
		  	position = "top";
		  }];
		  output = {
		  	"*" = {
		  	  #bg = "${config.home.homeDirectory}/Pictures/Wallpapers/New Gridania.jpeg fill";
		  	  bg = "${(builtins.toString ./theming/wallpapers/new_gridania.jpg)} fill";
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
		  	  hide_cursor = "20000";
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
		  	"$mod+Shift+d" = "exec \"rofi -modi 'drun,run' -theme ${config.xdg.dataHome}/rofi/themes/custom.rasi -show drun -drun-show-actions\"";
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

		  	  "$mod+w" = "output '*' disable; output HDMI-A-1 enable mode 2560x1440@120Hz pos 0 0 adaptive_sync on; exec pactl set-default-sinkalsa_output.pci-0000_0f_00.1.pro-output-3";
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
		  export QT_QPA_PLATFORMTHEME=qt6ct
		  export _JAVA_AWT_WM_NONREPARENTING=1
		  export MOZ_ENABLE_WAYLAND=1
		  export MOZ_DBUS_REMOTE=1
		  export XDG_CURRENT_DESKTOP=sway
		  export NIXOS_OZONE_WL=1
		  export WLR_RENDERER=vulkan

		  # Monitor the wayvnc process to see if it's still running
		  if pgrep -x "wayvnc" > /dev/null; then
		      sleep 1  # Wait a second if wayvnc is still running
		  fi

		  if [ -f /tmp/wayvnc_login ]; then
		    if ${pkgs.gawk}/bin/awk '
		    /Exiting.../ {e=1}
		    e && /Closing client connection/ {exit 0}
		    e && !/Closing client connection/ {exit 1}
		    ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/wayvnc_login); then
		      export REMOTE_ENABLED=1
		      export WLR_DRM_DEVICES=/dev/dri/card1
		      #export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 # Render sway on iGPU to use it for dGPU-maxed encoding
		      ${pkgs.openrgb}/bin/openrgb --mode static --color 000000 2> /dev/null || true
		    else
		      export REMOTE_ENABLED=0
		    fi
		  else
		    export REMOTE_ENABLED=0
		  fi

		  if [ -f /tmp/sunshine_login ]; then
		    if ${pkgs.gawk}/bin/awk '
		    /CLIENT CONNECTED/ {e=1}
		    e && /CLIENT DISCONNECTED/ {cancel=1}
		    END { if (e && !cancel) exit 0; else exit 1 }
		    ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/sunshine_login); then
		      export REMOTE_ENABLED=1
		      export WLR_DRM_DEVICES=/dev/dri/card1
		      #export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 # Render sway on iGPU to use it for dGPU-maxed encoding
		    else
		      export REMOTE_ENABLED=0
		    fi
		  else
		    export REMOTE_ENABLED=0
		  fi

		  export WLR_NO_HARDWARE_CURSORS="''${WLR_NO_HARDWARE_CURSORS:-$REMOTE_ENABLED}"
		  #export WLR_BACKENDS=$([ $REMOTE_ENABLED = 1 ] && echo "headless,libinput" || echo "drm,libinput")
		    
		  eval $(gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)
		  export SSH_AUTH_SOCK
	    '';
	};

	# """ # Workaround to fix highlighting

	services = {
	  kanshi = {
	    enable = true;
	    systemdTarget = "";
	  };

	  mako = {
	    enable = true;

	  	font = "${config.gtk.font.name} 11";
	  	layer = "overlay";
	  	defaultTimeout = 4000;
	  	borderRadius = 6;
	  	borderSize = 2;
	  	maxIconSize = 32;
	  	anchor = "top-right";

	  	backgroundColor = "#${config.colorScheme.palette.base00}";
	  	borderColor = "#${config.colorScheme.palette.base0D}";
	  	progressColor = "#${config.colorScheme.palette.base0D}";
	  	textColor = "#${config.colorScheme.palette.base05}";

	  	extraConfig =
''
[urgency=low]
text-color=#${config.colorScheme.palette.base0A}

[urgency=high]
text-color=#${config.colorScheme.palette.base08}
'';
	  };
	};

  home = {
    packages = with pkgs; [
      wl-gammarelay-rs
      libsForQt5.qt5ct
      qt6Packages.qt6ct
    ];
  };
}
