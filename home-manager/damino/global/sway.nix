{ inputs, lib, config, pkgs, ... }: {
	imports = [
      inputs.chaotic.homeManagerModules.default
      ./wlogout.nix
      ./waybar.nix
      ./rofi.nix
	];

	#nix.package = pkgs.nix;

	wayland.windowManager.sway = {
		enable = true;
		#package = pkgs.sway_git;
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
		      existing_headless=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\")) | .name")
		      
		      if [ -z "$existing_headless" ]; then
		        # If no HEADLESS output exists, create one
		        swaymsg create_output
		      fi
		      # Disable all non-HEADLESS outputs
		      swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name | test(\"HEADLESS\") | not).name" | ${pkgs.findutils}/bin/xargs -r -I{} ${pkgs.sway}/bin/swaymsg output {} disable
		      swaymsg output "*" render_bit_depth 10
		    else
		      # If not remote, run kanshi
		      ${pkgs.coreutils}/bin/timeout 10 ${pkgs.kanshi}/bin/kanshi
		    fi
		  '';

		  # Taken from https://gist.github.com/GrabbenD/adc5a7a863cbd1553461376cf4c50467
		  vrrFullscreen = pkgs.writeShellScript "sway-vrr-fullscreen.sh" ''
		    #!/usr/bin/env bash
		    rm -f "$XDG_RUNTIME_DIR"/sway_vrr_lock || true
		    output_vrr_whitelist=(
		      "DP-1"
		      "HDMI-A-1"
		    )
		    
		    # Toggle VRR for fullscreened apps in prespecified displays to avoid stutters while in desktop
		    swaymsg -t subscribe -m '[ "window" ]' | while read window_json; do
		      window_event=$(echo ''\${window_json} | ${pkgs.jq}/bin/jq -r '.change')

		      # Process only focus change and fullscreen toggle
		      if [[ $window_event = "focus" || $window_event = "fullscreen_mode" ]]; then
		        output_json=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused == true)')
		        output_name=$(echo ''\${output_json} | ${pkgs.jq}/bin/jq -r '.name')

		        # Use only VRR in whitelisted outputs
		        if [[ ! -e "$XDG_RUNTIME_DIR"/sway_vrr_lock ]] && [[ ''\${output_vrr_whitelist[*]} =~ ''\${output_name} ]]; then
		          output_vrr_status=$(echo ''\${output_json} | ${pkgs.jq}/bin/jq -r '.adaptive_sync_status')
		          window_fullscreen_status=$(echo ''\${window_json} | ${pkgs.jq}/bin/jq -r '.container.fullscreen_mode')

		          # Only update output if nesseccary to avoid flickering
		          [[ $output_vrr_status = "disabled" && $window_fullscreen_status = "1" ]] && swaymsg output "''\${output_name}" adaptive_sync 1
		          [[ $output_vrr_status = "enabled" && $window_fullscreen_status  = "0" ]] && swaymsg output "''\${output_name}" adaptive_sync 0
		        fi
		      fi
		    done
		  '';
		satellite-steam-unfloat-fix = pkgs.writeShellScript "satellite-steam-unfloat-fix.sh" ''
          declare -A last_floating
          debounce_ms=200
          ignore_until=0

          swaymsg -t subscribe -m '["window"]' |
          while read -r event; do
            now=$(date +%s%3N)
            if [ "$now" -lt "$ignore_until" ]; then
              continue
            fi

            id=$(${pkgs.jq}/bin/jq -r '.container.id // empty' <<<"$event")
            app_id=$(${pkgs.jq}/bin/jq -r '.container.app_id // empty' <<<"$event")
            tag=$(${pkgs.jq}/bin/jq -r '.container.tag // empty' <<<"$event")
            floating=$(${pkgs.jq}/bin/jq -r '.container.floating // empty' <<<"$event")
            visible=$(${pkgs.jq}/bin/jq -r '.container.visible // false' <<<"$event")
            fullscreen=$(${pkgs.jq}/bin/jq -r '.container.fullscreen_mode // 0' <<<"$event")

            # Only care about visible Steam windows
            if ([ "$app_id" = "steam" ] || [ "$app_id" = "steam_app_"* ]) && [ "$tag" = "" ] && [ "$visible" = "true" ]; then
              # "''$()"
              prev=''${last_floating[$id]:-auto_off}

              # Trigger sequence ONLY when window just exited floating and is NOT fullscreen
              if [ "$prev" != "auto_off" ] && [ "$floating" = "auto_off" ] && [ "$fullscreen" != "1" ]; then
                echo "Doing"
                ignore_until=$(( now + debounce_ms ))
                last_floating[$id]=$floating

                # Fix xwayland-satellite scaling
                swaymsg "[con_id=$id] floating enable"
                sleep 0.1
                swaymsg "[con_id=$id] fullscreen enable"
                sleep 0.1
                swaymsg "[con_id=$id] floating disable"
                sleep 0.1
                swaymsg "[con_id=$id] fullscreen disable"
              else
                # Update last_floating if nothing triggered
                last_floating[$id]=$floating
              fi
            fi
          done
          # "''$()"
        '';
		in
		''
		  exec systemctl --user restart xdg-desktop-portal
		  
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
          # Start recording only on desktops (dGPU heuristic)
          exec sh -c "ls \"$XDG_RUNTIME_DIR/dri\" 2> /dev/null | ${pkgs.gnugrep}/bin/grep -q dgpu && systemctl --user restart gpu-screen-recorder"
          exec_always sh -c "sleep 1; systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder"

		  #exec mako
		  exec ${pkgs.swaynotificationcenter}/bin/swaync
		  exec ${pkgs.networkmanagerapplet}/bin/nm-applet
		  exec_always ${pkgs.autotiling-rs}/bin/autotiling-rs
		  exec ${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs
		  exec ${vrrFullscreen}
		  exec ${satellite-steam-unfloat-fix}

		  exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -ne 1 ]; then swaymsg "workspace 1 output DP-1; workspace 2 output DP-2; workspace 4 output DP-1; workspace 1; exec firefox; workspace 2; exec discord; workspace 1; exec (sleep 3 && gtk-launch steam.desktop); workspace 1"; fi'
		  #exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -ne 1 ]; then gtk-launch firefox.desktop; fi'
		  #exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -ne 1 ]; then gtk-launch vesktop.desktop; fi'
		  #exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -ne 1 ]; then gtk-launch discord.desktop; fi'
		  #exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -ne 1 ]; then gtk-launch steam.desktop; fi'
		  exec ${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --selection-size-limit 209715200 --reconnect-tries 1 --all-mime-type-regex '(?i)^(?!image/x-inkscape-svg).+'
		  exec sh -c 'if [ "''${REMOTE_ENABLED:-0}" -eq 1 ]; then sleep 5 && ${pkgs.systemd}/bin/systemctl --user restart sunshine; fi'
		'';

		config = {
		  #modifier = "Mod4";
		  window = {
		    commands = let proton-borderless-fs-fix = pkgs.writeShellScript "proton-borderless-fs-fix.sh" ''
		      #!/usr/bin/env bash
		      # Fix for Proton Wayland games positioning weirdly in borderless mode

              sleep 1
		      # Identify the focused monitor's resolution
		      read OUT_W OUT_H < <(
		        swaymsg -t get_outputs |
		          ${pkgs.jq}/bin/jq -r '
		            map(select(.focused == true))[0]
		            | "\(.current_mode.width) \(.current_mode.height)"
		          '
		      )
		      [ -z "$OUT_W" ] || [ -z "$OUT_H" ] && exit 0

		      # Identify the focused window
		      # (for_window rules guarantee the new window is focused)
		      read WIN_W WIN_H FLOATING < <(
		        swaymsg -t get_tree |
		          ${pkgs.jq}/bin/jq -r '.. | objects | select(.focused? == true) | "\(.geometry.width) \(.geometry.height) \(.floating)"' |
		          head -n1
		      )
		      [ -z "$WIN_W" ] || [ -z "$WIN_H" ] && exit 0

		      # Compare dimensions: Floating window matches output == "borderless fullscreen" -> Force fullscreen
		      if [[ "$FLOATING" == "user_on" ]] && [ "$WIN_W" -eq "$OUT_W" ] && [ "$WIN_H" -eq "$OUT_H" ]; then
		        swaymsg [con_id="__focused__"] floating disable
		        sleep 1
		        swaymsg [con_id="__focused__"] fullscreen enable
		      fi
		    ''; in [
		  	  {
		        command = "move scratchpad";
		    	criteria = { instance = "scratchpad"; };
		      }
		      {
		      	command = "border pixel 2";
		      	criteria = { class = "^.*"; };
		      }
		      {
		      	command = "inhibit_idle fullscreen";
		      	criteria = { title = "Steam Big Picture Mode"; };
		      }
		      {
		        command = "inhibit_idle fullscreen";
		        criteria = { class = "^.*"; };
		      }
		      {
		        command = "inhibit_idle fullscreen";
		        criteria = { app_id = "^.*"; };
		      }
		      # TODO: See if matching on content_type works in the future (to match "game")
		      {
		        command = "exec ${proton-borderless-fs-fix}";
		        criteria = { tag = ".*game.*"; }; # Wayland native
		      }
		      {
		        command = "exec ${proton-borderless-fs-fix}";
		        criteria = { app_id = "^steam_app_.*"; }; # XWayland
		      }
		      # https://github.com/ValveSoftware/gamescope/issues/645#issuecomment-1772740921
		      {
		        command = "move output current ; workspace back_and_forth ; workspace back_and_forth";
		        #command = "exec sh -c 'orig=$(swaymsg -t get_workspaces | ${pkgs.jq}/bin/jq -r \".[] | select(.focused).name\") && swaymsg move output current && swaymsg workspace __temp__ && swaymsg workspace \"$orig\"'";
		        criteria = { app_id = "gamescope"; };
		      }
		      {
		        command = "move output current ; workspace back_and_forth ; workspace back_and_forth";
		        #command = "exec sh -c 'orig=$(swaymsg -t get_workspaces | ${pkgs.jq}/bin/jq -r \".[] | select(.focused).name\") && swaymsg move output current && swaymsg workspace __temp__ && swaymsg workspace \"$orig\"'";
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
		  	  bg = "${./theming/wallpapers/new_gridania.jpg} fill";
		  	};
		  };
          input = {
            "type:pointer" = { accel_profile = "flat"; };
            "type:touchpad" = {
              tap = "enabled";
              natural_scroll = "enabled";
            };
          };
		  focus.mouseWarping = "container";
		  seat = {
		  	"*" = {
		  	  hide_cursor = "10000";
		  	  xcursor_theme = "${config.gtk.cursorTheme.name} 25";
		  	};
		  	
		  };
		  gaps = {
		  	smartGaps = true;
		  	smartBorders = "on";
		  	inner = 4;
		  	outer = 0;
		  };
		  keybindings = let
		  bind-hold = pkgs.writeShellScript "bind-hold" ''
		    # Usage: bind-hold <action> <id> [start_cmd] [charged_cmd]
		    
		    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
		    statefile="''${runtime_dir}/charge_state_$2"
		    pidfile="''${statefile}.pid"
		    
		    # Default commands if not supplied
		    start_cmd="''${3:-notify-send 'Charging'}"
		    charged_cmd="''${4:-notify-send 'Charged!'}"
		    # "''$()"
		    
		    case "$1" in
		      start)
		        # If already charging, do nothing
		        if [[ -f "$statefile" ]]; then
		          exit 0
		        fi
		    
		        # Execute start command
		        eval "$start_cmd"
		        touch "$statefile"
		    
		        (
		          sleep 1
		          # Only execute charged command if still held
		          if [[ -f "$statefile" ]]; then
		            eval "$charged_cmd"
		          fi
		        ) &
		        echo $! > "$pidfile"
		        ;;
		      stop)
		        # Cancel timer process if running
		        if [[ -f "$pidfile" ]]; then
		          kill "$(cat "$pidfile")" 2>/dev/null
		          rm -f "$pidfile"
		        fi
		        rm -f "$statefile"
		        ;;
		    esac
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
		  hdr-screenshot = pkgs.writeShellScript "hdr-screenshot" ''
		    mode="$1"
		    tmpfile=$(${pkgs.mktemp}/bin/mktemp)
		    HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
		    trap 'rm -f "$tmpfile && swaymsg output $HEADLESS unplug 2> /dev/null"' EXIT
		    
            if [[ -z "$HEADLESS" ]]; then
              echo "No headless output found, creating one..." >&2
              swaymsg create_output > /dev/null 2>&1 &
              HEADLESS=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
            fi

            set_headless_mode() {
              local display="$1"
              DISPLAY_INFO=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$display\")")
              # Get resolution, scale, and refresh rate
              WIDTH=$(${pkgs.jq}/bin/jq   -r '.current_mode.width'   <<< "$DISPLAY_INFO")
              HEIGHT=$(${pkgs.jq}/bin/jq  -r '.current_mode.height'  <<< "$DISPLAY_INFO")
              REFRESH=$(${pkgs.jq}/bin/jq -r '.current_mode.refresh' <<< "$DISPLAY_INFO")
              SCALE=$(${pkgs.jq}/bin/jq   -r '.scale'  <<< "$DISPLAY_INFO")
              XPOS=$(${pkgs.jq}/bin/jq    -r '.rect.x' <<< "$DISPLAY_INFO")
              YPOS=$(${pkgs.jq}/bin/jq    -r '.rect.y' <<< "$DISPLAY_INFO")
              REFRESH=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.3f\", $REFRESH / 1000 }")

              swaymsg output $HEADLESS mode "$WIDTH"x"$HEIGHT"@"$REFRESH"Hz enable pos "$XPOS" "$YPOS" scale "$SCALE" > /dev/null 2>&1 &
            }
            
            # Prefer overlapping HEADLESS outputs for HDR tonemapping
		    case "$mode" in
		      focused)
		        output=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
                set_headless_mode $output

		        ${pkgs.grim}/bin/grim -o "$HEADLESS" "$tmpfile"
		        ;;
		      select|selector)
		        REGION=$(${pkgs.slurp}/bin/slurp) || exit 1
		        read XY WH <<<"$REGION"
		        X=''${XY%,*}      # before comma
		        Y=''${XY#*,}      # after comma
		        W=''${WH%x*}      # before x
		        H=''${WH#*x}      # after x

		        # Get all outputs that intersect the region
		        OUTPUTS=$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r --argjson x "$X" --argjson y "$Y" --argjson w "$W" --argjson h "$H" '
		          .[] | select(.active) |
		          select(
		            # Check if rectangles intersect
		            (.rect.x + .rect.width  > $x) and
		            ($x + $w > .rect.x) and
		            (.rect.y + .rect.height > $y) and
		            ($y + $h > .rect.y)
		          ) | .name
		        ')

                # If exactly one output intersects, store in a variable
                #${pkgs.libnotify}/bin/notify-send "$OUTPUTS"
                if [[ ''${#OUTPUTS[@]} -eq 2 ]]; then
                  TARGET_OUTPUT="''${OUTPUTS[0]}"
                  if [[ "''${OUTPUTS[0]}" == "HEADLESS*" ]]; then
                    set_headless_mode "''${OUTPUTS[1]}"
                    ${pkgs.grim}/bin/grim -o "''${OUTPUTS[0]}" -g "$REGION" "$tmpfile"
                  elif [[ "''${OUTPUTS[1]}" == "HEADLESS*" ]]; then
                    set_headless_mode "''${OUTPUTS[0]}"
                    ${pkgs.grim}/bin/grim -o "''${OUTPUTS[1]}" -g "$REGION" "$tmpfile"
                  else
                    ${pkgs.grim}/bin/grim -g "$REGION" "$tmpfile"
                  fi
                elif [[ ''${#OUTPUTS[@]} -eq 1 ]]; then
                  set_headless_mode "''${OUTPUTS[0]}"
                  # grim doesn't take -o and -g, but seems to just prioritize HEADLESS
                  ${pkgs.grim}/bin/grim -g "$REGION" "$tmpfile"
                else
                  ${pkgs.libnotify}/bin/notify-send "BRANCH5"
                  ${pkgs.grim}/bin/grim -g "$REGION" "$tmpfile"
                fi
		        ;;
		      *)
		        echo "Usage: $0 {focused|select}" >&2
		        swaymsg output $HEADLESS unplug 2> /dev/null
		        exit 1
		        ;;
		    esac

		    if [[ -s "$tmpfile" ]]; then
		      ${pkgs.wl-clipboard-rs}/bin/wl-copy --type image/png < "$tmpfile"
		      # cat "$tmpfile" | ${pkgs.wl-clipboard-rs}/bin/wl-copy --type image/png
		      ${pkgs.libnotify}/bin/notify-send -a "Screenshot" -i "$tmpfile" "Screenshot taken"
		    fi
		    swaymsg output $HEADLESS unplug 2> /dev/null
		    # "''$()"
		  ''; in {
		    #"$mod+t" = "exec ${bind-hold} start t";
		    #"--release $mod+t" = "exec ${bind-hold} stop t";
		    "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
		    "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
		    "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
		    "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
		  	#"XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%";
		  	#"XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%";
		  	#"XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle";
		  	#"XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SINK@ toggle";
		  	"Control+grave" = "exec ${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel";
		  	"Control+space" = "exec ${pkgs.swaynotificationcenter}/bin/swaync-client --hide-latest";
		  	#"Control+grave" = "exec makoctl restore";
		  	#"Control+space" = "exec makoctl dismiss";
		  	"Control+Shift+b" = "exec sway-toggle-hdr";
		  	"$mod+Return" = "exec alacritty";
		  	"$mod+Shift+q" = "kill";
		  	"$mod+d" = "exec \"rofi -modi 'drun,run' -theme ${config.xdg.dataHome}/rofi/themes/custom.rasi -show drun\"";
		  	"$mod+Shift+d" = "exec \"rofi -modi 'drun,run' -theme ${config.xdg.dataHome}/rofi/themes/custom.rasi -show drun -drun-show-actions\"";
			"$mod+h" = "split h";
			"$mod+v" = "split v";
			"$mod+f" = "fullscreen toggle";
			#"$mod+s" = "layout stacking";
			#"$mod+w" = "layout tabbed";
			#"$mod+e" = "layout toggle split";
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

			"Shift+Print" = "exec ${hdr-screenshot} select";
			"Shift+Prior" = "exec ${hdr-screenshot} select";
			"Print" = "exec ${hdr-screenshot} focused";
			"Shift+Next" = "exec ${hdr-screenshot} focused";

			# Save replay if gpu-screen-recorder -r is running
			#"Control+Print" = "exec ${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service && ${pkgs.libnotify}/bin/notify-send -a 'gpu-screen-recorder' 'Saving replay...'";
			"Control+Print" = "exec ${bind-hold} start gsc-replay \"${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service && ${pkgs.libnotify}/bin/notify-send -a 'gpu-screen-recorder' 'Saving replay...'\" \"killall -SIGUSR1 gpu-screen-recorder\"";
			"Control+Shift+Next" = "exec ${bind-hold} start gsc-replay \"${pkgs.systemd}/bin/systemctl --user is-active --quiet gpu-screen-recorder.service && ${pkgs.libnotify}/bin/notify-send -a 'gpu-screen-recorder' 'Saving replay...'\" \"killall -SIGUSR1 gpu-screen-recorder\"";
			"--release Control+Print" = "exec ${bind-hold} stop gsc-replay";
			"--release Control+Shift+Next" = "exec ${bind-hold} stop gsc-replay";

			# Start / stop manual recording if gpu-screen-recorder -ro is running
			"Control+Shift+Print" = "exec ${bind-hold} start gsc-record ${checkrec} ${screenrec}";
			"Control+Shift+Prior" = "exec ${bind-hold} start gsc-record ${checkrec} ${screenrec}";
			"--release Control+Shift+Print" = "exec ${bind-hold} stop gsc-record";
			"--release Control+Shift+Prior" = "exec ${bind-hold} stop gsc-record";
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

			  "$mod+o" = "exec timeout 10 kanshi";
		  	};
		  };

		  assigns = {
		    "2" = [
		      { app_id="discord"; }
		    ];
		  	"4" = [
		  	  { instance="steamwebhelper"; }
		  	  { app_id="steam"; }
		  	];
		  };
		};

	    extraSessionCommands = let satellite-wrapper = pkgs.writeShellScriptBin "satellite-wrapper" ''
	      # Subsequent calls probably belong to gamescope
	      if [ "$1" != ":0" ]; then
	        exec ${pkgs.xwayland}/bin/Xwayland "$@"
	      else
	        # Try to force 1x scaling
	        swaymsg exec '${pkgs.xwayland-satellite}/bin/xwayland-satellite; sleep 1; ${pkgs.xorg.xrdb}/bin/xrdb -merge <<< "Xft.dpi: 96"'
	      fi
	    '';
	    in ''
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
		  #export WLR_RENDERER=vulkan

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
		      #export WLR_DRM_DEVICES=/dev/dri/card1
		      export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0
		      #export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 # Render sway on iGPU to use it for dGPU-maxed encoding
		      ${pkgs.openrgb}/bin/openrgb --mode static --color 000000 2> /dev/null || true
		    else
		      export REMOTE_ENABLED=0
		    fi
		  else
		    export REMOTE_ENABLED=0
		  fi

		  if [[ "$(${pkgs.systemd}/bin/systemctl --user is-active sunshine.service 2>/dev/null)" == "active" ]] || \
		     ( [ -f /tmp/sunshine_login ] && ${pkgs.gawk}/bin/awk '
		        /CLIENT CONNECTED/ {e=1}
		        e && /CLIENT DISCONNECTED/ {cancel=1}
		        END { if (e && !cancel) exit 0; else exit 1 }
		      ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/sunshine_login) ); then
		    export REMOTE_ENABLED=1
		    #export WLR_DRM_DEVICES=/dev/dri/card1
		    export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0
		    #export WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 # Render sway on iGPU to use it for dGPU-maxed encoding
		    ${pkgs.openrgb}/bin/openrgb --mode static --color 000000 2> /dev/null || true
		  else
		    export REMOTE_ENABLED=0
		  fi

		  ${pkgs.systemd}/bin/systemctl --user set-environment REMOTE_ENABLED=$REMOTE_ENABLED

		  export WLR_NO_HARDWARE_CURSORS="''${WLR_NO_HARDWARE_CURSORS:-$REMOTE_ENABLED}"
		  #export WLR_BACKENDS=$([ $REMOTE_ENABLED = 1 ] && echo "headless,libinput" || echo "drm,libinput")
		  export WLR_RENDERER=$([ $REMOTE_ENABLED = 1 ] && echo "gles2" || echo "vulkan")
		  #export WLR_RENDER_NO_EXPLICIT_SYNC=1
		    
		  eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)
		  # eval returns nothing if keyring is already running, so check known location for existing socket
		  if [[ ! -v SSH_AUTH_SOCK && -S "$XDG_RUNTIME_DIR/gcr/ssh" ]]; then
		    SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
		  fi
		  export SSH_AUTH_SOCK
		  export SSH_ASKPASS=${pkgs.seahorse.out}/libexec/seahorse/ssh-askpass
		  export WLR_XWAYLAND=${satellite-wrapper}/bin/satellite-wrapper
	    '';
	};

	# """ # Workaround to fix highlighting

    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
	xdg.portal.config = {
	  sway = {
	    default = [ "gtk" ];
	    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
	    "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
	  };
	};

	services = {
	  kanshi = {
	    enable = true;
	    systemdTarget = "";
	  };

	  mako = {
	    enable = true;
        settings = {
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

          "urgency=low" = {
            text-color = "#${config.colorScheme.palette.base0A}";
          };
          "urgency=high" = {
            ext-color = "#${config.colorScheme.palette.base08}";
          };
        };
	  };
	};

  home = {
    file = {
      ".config/xdg-desktop-portal-wlr/config" = let headless-share = pkgs.writeShellScript "headless-share.sh" ''
        display=$(${pkgs.slurp}/bin/slurp -f "%o" -or)
        echo "Display: $display" >&2

        is_hdr="$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$display\") | .hdr")"
        if [[ "$is_hdr" != "true" ]]; then
          echo "Monitor: $display"
          exit 0
        fi

        # Find existing headless output (match by name prefix)
        HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
        
        if [[ -z "$HEADLESS" ]]; then
          echo "No headless output found, creating one..." >&2
          ${pkgs.sway}/bin/swaymsg create_output > /dev/null 2>&1 &
          HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
        fi
        
        if [[ -z "$HEADLESS" ]]; then
          echo "Failed to create or find a headless output." >&2
          exit 1
        fi

        DISPLAY_INFO=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$display\")")

        if [[ -z "$DISPLAY_INFO" ]]; then
          echo "Could not find output $display." >&2
          exit 1
        fi

        echo "Display: $display" >&2
        echo "Headless: $HEADLESS" >&2
        
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

        echo "Monitor: $HEADLESS"
      '';
      headless-unplug = pkgs.writeShellScript "headless-unplug.sh" ''
        # Find existing headless output (match by name prefix)
        HEADLESS=$(${pkgs.sway}/bin/swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^HEADLESS-")) | .name' | ${pkgs.coreutils}/bin/head -n1)
        if [[ -z "$HEADLESS" ]]; then
          echo "Failed to create or find a headless output."
          exit 0
        fi
        ${pkgs.sway}/bin/swaymsg output "$HEADLESS" unplug > /dev/null 2>&1 &
      ''; in lib.mkDefault {
        text = ''
          [screencast]
          max_fps=60
          chooser_cmd=${headless-share}
          exec_after=${headless-unplug}
          #chooser_cmd=${pkgs.slurp}/bin/slurp -f "Monitor: %o" -or
          chooser_type=simple
        '';
      };
    };
    packages = with pkgs; [
      xwayland-satellite
      wl-gammarelay-rs
      libsForQt5.qt5ct
      qt6Packages.qt6ct
    ] ++ [
      (pkgs.writeShellScriptBin "sway-toggle-hdr" ''
        focused_display="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')"
        supports_hdr="$(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r ".[] | select(.name==\"$focused_display\") | .features.hdr")"
        if [[ "$supports_hdr" != "true" ]]; then
          echo "Display $focused_display does not support HDR: $supports_hdr"
          exit 1
        fi
        swaymsg output "$focused_display" hdr toggle
        sleep 1; systemctl --user is-active --quiet gpu-screen-recorder && systemctl --user reload gpu-screen-recorder
      '')
    ];
  };
}
