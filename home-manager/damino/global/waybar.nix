{ inputs, config, pkgs, ... }: {
  programs.waybar = {
	enable = true;

	settings = {
	  mainBar = {
	    ipc = true;
	  	layer = "top";
	  	height = 22;
	  	modules-left = [ "sway/workspaces" "sway/mode" ];
	  	modules-center = [ "clock" ];
	  	modules-right = [ "pulseaudio" "custom/weather" "tray" "custom/nwg-menu" ];

	  	"sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format-icons = {
            urgent = "";
            focused = "";
            default = "";
          };
     	};

     	"sway/mode" = {
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
            # get_weather.sh
            for i in {1..5}
            do
                #text=$(curl -s "https://wttr.in/$1?format=1")
                text=$(curl -s "https://wttr.in/$1?format=%c+%t")
                if [[ $? == 0 ]]
                then
                	text=$(echo "$text" | tr -d +)
                    text=$(echo "$text" | sed -E "s/\s+/ /g")
                    tooltip=$(curl -s "https://wttr.in/$1?format=4")
                    if [[ $? == 0 ]]
                    then
                        tooltip=$(echo "$tooltip" | sed -E "s/\s+/ /g")
                        echo "{\"text\":\"$text\", \"tooltip\":\"$tooltip\"}"
                        exit
                    fi
                fi
                sleep 2
            done
            echo "{\"text\":\"error\", \"tooltip\":\"error\"}"
          '';
          return-type = "json";
          format = "{}";
          tooltip = true;
          interval = 3600;
    	};

    	"custom/nwg-menu" = {
    	  #format = "{}";
    	  interval = 10;
    	  format = "{icon}    ";
	      format-icons = {
            default = "";
          };
		  on-click = "${pkgs.nwg-menu}/bin/nwg-menu -fm nautilus -ha right -va top";
    	};

    	"pulseaudio" = {
          # "scroll-step": 1, // %, can be a float
          #"format": "{volume}% {icon} {format_source}",
          #"format-bluetooth": "{volume}% {icon} {format_source}",
          format-bluetooth = "{volume}% {icon}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
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
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
    	};
	  };
	};
	
	style = ''
/* Start flavours */
/*
*
* Base16 Mocha
* Author: Chris Kempson (http://chriskempson.com)
*
*/

@define-color base00 #3b3228;
@define-color base01 #534636;
@define-color base02 #645240;
@define-color base03 #7e705a;
@define-color base04 #b8afad;
@define-color base05 #d0c8c6;
@define-color base06 #e9e1dd;
@define-color base07 #f5eeeb;
@define-color base08 #cb6077;
@define-color base09 #d28b71;
@define-color base0A #f4bc87;
@define-color base0B #beb55b;
@define-color base0C #7bbda4;
@define-color base0D #8ab3b5;
@define-color base0E #a89bb9;
@define-color base0F #bb9584;
/* End flavours */

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
    background-color: @base00;
    color: @base07;
    transition-property: background-color;
    transition-duration: .5s;
    opacity: 0.8;
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
    background-color: @base00;
}

#workspaces button.urgent {
    background-color: @base00;
}

#mode {
    background-color: #64727D;
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


#pulseaudio.muted {
    background-color: #90b1b1;
    color: #2a5c45;
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
'';
  };
}
