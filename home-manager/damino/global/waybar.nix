{ inputs, config, pkgs, ... }: {
  home.packages = with pkgs; [ font-awesome noto-fonts-color-emoji noto-fonts-monochrome-emoji twemoji-color-font ];
  programs.waybar = {
	enable = true;

	settings = {
	  mainBar = {
	    ipc = true;
	    position = "top";
	  	layer = "top";
	  	mode = "dock";
	  	height = 22;
	  	modules-left = [ "sway/workspaces" "sway/mode" "hyprland/workspaces" "hyprland/submap" ];
	  	modules-center = [ "clock" ];
	  	modules-right = [ "pulseaudio" "bluetooth" "custom/weather" "custom/nightlight" "tray" "custom/menu" ];
	  	#modules-right = [ "pulseaudio" "group/extras" "custom/menu" ];

	  	"group/extras" = {
	  	  orientation = "horizontal";
	  	  drawer = {
	  	    "transition-duration" = 300;
	  	    "children-class" = "tray-children";
	  	  };
	  	  "modules" = [
	  	    "custom/weather"
	  	    "bluetooth"
	  	    "custom/nightlight"
	  	    "tray"
	  	  ];
	  	};

	  	"sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format-icons = {
            urgent = "";
            focused = "";
            default = "";
          };
     	};

     	"bluetooth" = {
     	  format-on = " 󰂯 ";
     	  format-off = " 󰂲";
     	  format-disabled = "";
     	  format-connected = " 󰂱 ";
     	  #format-connected = "󰂱 {num_connections} ";
     	  tooltip-format-connected = "{device_enumerate}";
     	  tooltip-format-enumerate-connected = "{device_alias}\t{device_battery_percentage}%";
     	  #tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
     	  on-click = "kill `pgrep blueberry` || ${pkgs.blueberry}/bin/blueberry";
     	};

     	"sway/mode" = {
          format = "<span style=\"italic\">{}</span>";
		};

		"hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format-icons = {
            urgent = "";
            focused = "";
            default = "";
          };
     	};

     	"hyprland/submap" = {
          format = "<span style=\"italic\">{}</span>";
		};

		"tray" = {
          spacing = 10;
    	};

    	"clock" = {
          timezone = "America/New_York";
          format = "{:%I:%M %p}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "   {:%Y-%m-%d}";
    	};

    	"battery" = {
          states = {
            #"good": 95,
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          # "format-good": "", // An empty format will hide the module
          # "format-full": "",
          format-icons = [ "" "" "" "" "" ];
    	};

    	"battery#bat2" = {
          bat = "BAT2";
    	};

    	"network" = {
          # "interface": "wlp2*", // (Optional) To force the use of this interface
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
    	};

    	"custom/weather" = {
          exec = pkgs.writeShellScript "get_weather" ''
            #!/usr/bin/env bash
            
            CACHE_DIR="/home/$USER/.config/waybar"
            CACHE_FILE="$CACHE_DIR/weather.json"
            LOCK_FILE="$CACHE_DIR/weather.lock"
            MAX_AGE=$((30 * 60)) # 30 minutes
            
            mkdir -p "$CACHE_DIR"
            
            # Check if cache exists and is fresh enough
            if [[ -f "$CACHE_FILE" ]]; then
              now=$(date +%s)
              mtime=$(stat -c %Y "$CACHE_FILE")
              age=$((now - mtime))

              if [[ $age -lt $MAX_AGE ]]; then
                cat "$CACHE_FILE"
                exit 0
              fi
            fi

            # Use flock to ensure only one curl runs at a time
            exec 9>"$LOCK_FILE"
            flock -x 9

            # Double-check cache again after obtaining lock
            if [[ -f "$CACHE_FILE" ]]; then
              now=$(date +%s)
              mtime=$(stat -c %Y "$CACHE_FILE")
              age=$((now - mtime))

              if [[ $age -lt $MAX_AGE ]]; then
                cat "$CACHE_FILE"
                exit 0
              fi
            fi

            # Perform the fetch, retrying up to 5 times
            for i in {1..5}; do
              text=$(curl -s 'https://wttr.in/$1?format=%c+%t')
              if [[ $? -eq 0 && -n "$text" ]]; then
                # Detect "busy" response
                if [[ "$text" == *"This query is already being processed"* ]]; then
                  sleep 60
                  continue
                fi
            
                text=$(echo "$text" | tr -d + | sed -E "s/\s+/ /g")
            
                tooltip=$(${pkgs.curl}/bin/curl -s 'https://wttr.in/$1?format=4')
                if [[ $? -eq 0 && -n "$tooltip" ]]; then
                  if [[ "$tooltip" == *"This query is already being processed"* ]]; then
                    sleep 60
                    continue
                  fi

                  tooltip=$(echo "$tooltip" | sed -E "s/\s+/ /g")
                  result="{\"text\":\"$text\", \"tooltip\":\"$tooltip\"}"
                  echo "$result" | tee "$CACHE_FILE"
                  exit 0
                fi
              fi
              sleep 2
            done
            
            # Fallback
            echo "{\"text\":\"\", \"tooltip\":\"error\"}"
          '';
          return-type = "json";
          format = " {} ";
          tooltip = true;
          interval = 3600;
    	};

    	"custom/menu" = {
    	  #format = "{}";
    	  interval = 10;
    	  format = " {icon}    ";
	      format-icons = {
            default = "";
          };
		  on-click = '' ${pkgs.bash}/bin/bash -c "${pkgs.procps}/bin/pgrep -x rofi && ${pkgs.procps}/bin/pkill -x rofi || ${pkgs.rofi}/bin/rofi -modi 'drun,run' -theme ~/.local/share/rofi/themes/custom.rasi -show drun -location 3" '';
    	};

    	"pulseaudio" = {
          # "scroll-step": 1, // %, can be a float
          #"format": "{volume}% {icon} {format_source}",
          #"format-bluetooth": "{volume}% {icon} {format_source}",
          format-bluetooth = "{volume}% {icon}";
          format-bluetooth-muted = "󰝟  {icon}";
          format-muted = "󰝟 ";
          #"format-source": "{volume}% ",
          #"format-source-muted": "",
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "kill `pgrep pavucontrol` || ${pkgs.pavucontrol}/bin/pavucontrol";
    	};

    	"custom/nightlight" = let
    	  nightlight = pkgs.writeShellScript "nightlight" ''
    	    #!/usr/bin/env bash

            # Gammastep causes stutters when gaming. Kill it to take over
    	    kill -9 $(${pkgs.procps}/bin/pgrep gammastep) 2> /dev/null

    	    if ! ${pkgs.procps}/bin/pgrep -f wl-gammarelay-rs >/dev/null; then
    	      ${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs &
    	      sleep 0.5
    	    fi

    	    case "$1" in
    	      toggle)
    	        if ! ${pkgs.systemd}/bin/busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^q 6500$'; then
    	          ${pkgs.systemd}/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 6500
    	        else
    	          ${pkgs.systemd}/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 6000 &
    	        fi
    	        sleep 0.1 && pkill -RTMIN+10 waybar
    	        ;;
    	      increase)
    	        temp="$(${pkgs.systemd}/bin/busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature | ${pkgs.gawk}/bin/awk '{print $2}')"
    	        if [ "$temp" -ge 6500 ]; then
    	          ${pkgs.systemd}/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q 6500
    	        else
    	          ${pkgs.systemd}/bin/busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n +100
    	        fi
    	        sleep 0.1 && pkill -RTMIN+10 waybar
    	        ;;
    	      decrease)
    	        ${pkgs.systemd}/bin/busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n -100
    	        sleep 0.1 && pkill -RTMIN+10 waybar
    	        ;;
    	      status|*)
    	        temp="$(${pkgs.systemd}/bin/busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature | ${pkgs.gawk}/bin/awk '{print $2}')"K
    	        if ! ${pkgs.systemd}/bin/busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^q 6500$'; then
    	          echo "{\"text\":\"\",\"tooltip\":\"Color Temperature: $temp\"}"
    	        else
    	          echo "{\"text\":\"\",\"tooltip\":\"Color Temperature: $temp\"}"
    	        fi
    	        ;;
    	    esac
    	  '';
    	in {
    	  exec = "${nightlight} status";
    	  on-click = "${nightlight} toggle";
    	  on-scroll-up = "${nightlight} increase";
    	  on-scroll-down = "${nightlight} decrease";
    	  return-type = "json";
    	  signal = 10;
    	  format = "  {}  ";
    	};
	  };
	};
	
	style = ''
@define-color base00 #${config.colorScheme.palette.base00};
@define-color base01 #${config.colorScheme.palette.base01};
@define-color base02 #${config.colorScheme.palette.base02};
@define-color base03 #${config.colorScheme.palette.base03};
@define-color base04 #${config.colorScheme.palette.base04};
@define-color base05 #${config.colorScheme.palette.base05};
@define-color base06 #${config.colorScheme.palette.base06};
@define-color base07 #${config.colorScheme.palette.base07};
@define-color base08 #${config.colorScheme.palette.base08};
@define-color base09 #${config.colorScheme.palette.base09};
@define-color base0A #${config.colorScheme.palette.base0A};
@define-color base0B #${config.colorScheme.palette.base0B};
@define-color base0C #${config.colorScheme.palette.base0C};
@define-color base0D #${config.colorScheme.palette.base0D};
@define-color base0E #${config.colorScheme.palette.base0E};
@define-color base0F #${config.colorScheme.palette.base0F};

* {
    border: none;
    border-radius: 0;
    /* `otf-font-awesome` is required to be installed for icons */
    font-family: "Inter Medium", "Droid Sans", "Iosevka Nerd Font", Helvetica, Arial, sans-serif;
    font-size: 14px;
    font-weight: bold;
    padding: 0;
    margin: 0;
    color: @base07;
}

window#waybar {
    background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base00}, 0.95);
    color: @base07;
    transition-property: background-color;
    transition-duration: .5s;
    opacity: 1;
}

window#waybar.hidden {
    opacity: 0.2;
}

window#waybar.termite {
    background-color: #3F3F3F;
}

window#waybar.chromium {
    background-color: #000000;
    border: none;
}

#workspaces button {
    min-width: 10px;
    padding: 0 10px;
    background-color: transparent;
    color: @base07;
}

/* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
#workspaces button:hover {
    background: rgba(0, 0, 0, 0.2);
    box-shadow: inherit;
}

#workspaces button.focused {
    background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base00}, 0.6);
}

#workspaces button.urgent {
    background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base01}, 0.8);
}

#mode {
    background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base01}, 0.6);
}

#clock,
#battery,
#cpu,
#memory,
#temperature,
#backlight,
#network,
#pulseaudio,
#custom-media,
#tray,
#mode,
#idle_inhibitor,
#mpd {
    padding: 2px 5px;
    margin: 0 4px;
    color: @base07;
}

#custom-netcheck {
	font-family: "Iosevka Nerd Font";
	margin: 0 9px;
}

#battery {
    background-color: transparent;
    color: @base07;
}

label:focus {
    background-color: #000000;
}

#custom-media {
    background-color: #66cc99;
    color: #2a5c45;
    min-width: 100px;
}

#custom-media.custom-spotify {
    background-color: #66cc99;
}

#custom-media.custom-vlc {
    background-color: #ffa000;
}

#temperature {
    background-color: #f0932b;
}

#temperature.critical {
    background-color: #eb4d4b;
}

#idle_inhibitor.activated {
    background-color: #ecf0f1;
    color: #2d3436;
}

#mpd {
    background-color: #66cc99;
    color: #2a5c45;
}

#mpd.disconnected {
    background-color: #f53c3c;
}

#mpd.stopped {
    background-color: #90b1b1;
}

#mpd.paused {
    background-color: #51a37a;
}

/* menu rows / buttons */
.modelbutton, .menuitem, modelbutton, menuitem, .listboxrow, .listrow, .menu > * {
    padding: 2px 2px;
}

/* make context-menu text normal weight */
modelbutton > label,
.modelbutton > label,
menuitem > label,
.menuitem > label {
    font-weight: normal;
}
'';
  };
}
