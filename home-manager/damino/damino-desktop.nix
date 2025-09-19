{ inputs, pkgs, lib, ... }: {
	imports = [ ./global ];

	wayland.windowManager.hyprland = {
      settings = {
        env = [ "AQ_DRM_DEVICES,/dev/dri/card1" ];
        exec-once = [ "sleep 5 && systemctl --user start gpu-screen-recorder" ];
      };
      extraConfig = ''
        monitor = , preferred, auto, 1, mirror, DP-1
      '';
	};

	programs = {
	  rofi.yoffset = 24;
	};

	services = {
	  kanshi.settings = [
	    {
	      profile = {
	        name = "desktop";
	        outputs = [
	          {
	            criteria = "AOC Q27G40XMN 0x00000081";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
	      	    position = "0,0";
	      	    #adaptiveSync = true;
	      	  }
	          {
	      	    criteria = "AOC 24G1WG4 0x00042EBB";
	      	    status = "enable";
	      	    mode = "1920x1080@144.001";
	      	    position = "2560,250";
	      	    scale = 1.0;
	      	    adaptiveSync = false;
	      	  }
	      	  {
	      	    criteria = "Technical Concepts Ltd Beyond TV 0x00010000";
	      	    status = "disable";
	      	    adaptiveSync = false;
	      	  }
	        ];
	        exec = [
	          #"sh -c '${pkgs.sway}/bin/swaymsg output \"*\" render_bit_depth 10'" # Breaks xdg-desktop-portal-wlr/pipewire capture
	          "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	          #"${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_03_00.1 pro-audio"
	          #"${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3"
	        ];
	      };
	    }
	    {
	      profile = {
	        name = "desktop-headless";
	        outputs = [
	          {
	            criteria = "AOC Q27G40XMN 0x00000081";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
	      	    position = "0,0";
	      	    #adaptiveSync = true;
	      	  }
	          {
	      	    criteria = "AOC 24G1WG4 0x00042EBB";
	      	    status = "enable";
	      	    mode = "1920x1080@144.001";
	      	    position = "2560,250";
	      	    scale = 1.0;
	      	    adaptiveSync = false;
	      	  }
	      	  {
	      	    criteria = "Technical Concepts Ltd Beyond TV 0x00010000";
	      	    status = "disable";
	      	    adaptiveSync = false;
	      	  }
	      	  {
	      	    criteria = "Samsung Electric Company SAMSUNG 0x01000E00"; # Dummy display
	      	    status = "disable";
	      	    adaptiveSync = false;
	      	  }
	        ];
	        exec = [
	          #"sh -c '${pkgs.sway}/bin/swaymsg output \"*\" render_bit_depth 10'" # Breaks xdg-desktop-portal-wlr/pipewire capture
	          "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	          #"${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_03_00.1 pro-audio"
	          #"${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3"
	        ];
	      };
	    }
	  	{
	  	  profile = {
	  	    name = "desktop-old";
	  	    outputs = [
	  	      {
	  	        criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@143.999Hz";
	  	  	    position = "0,0";
	  	  	    adaptiveSync = true;
	  	  	  }
	  	      {
	  	  	    criteria = "AOC 24G1WG4 0x00042EBB";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@144.001";
	  	  	    position = "2560,360";
	  	  	    scale = 1.0;
	  	  	    adaptiveSync = false;
	  	  	  }
	  	  	  {
	  	  	    criteria = "Technical Concepts Ltd Beyond TV 0x00010000";
	  	  	    status = "disable";
	  	  	    adaptiveSync = true;
	  	  	  }
	  	    ];
	  	    exec = [
	  	      "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_0c_00.1 pro-audio"
	  	      "${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_0c_00.1.pro-output-10"
	  	    ];
	  	  };
	  	}
	  	{
	  	  profile = {
	  	    name = "desktop-secondary-old";
	  	    outputs = [
	  	      {
	  	        criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@143.999Hz";
	  	  	    position = "1920,0";
	  	  	    #position = "2560,0";
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	      {
	  	  	    criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75";
	  	  	    position = "0,180";
	  	  	    #position = "0,0";
	  	  	    #scale = 0.75;
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	    ];
	  	    exec = [
	  	      "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_0a_00.1 pro-audio"
	  	      "${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_0a_00.1.pro-output-3"
	  	    ];
	  	  };
	  	}
	  ];

	  mako.settings = {
	    output = "DP-2";
	    anchor = lib.mkForce "top-left";
	  };
	};

	home.file = {
	  ".config/hypr/hm/displays.conf" = {
	    text = ''
	      monitorv2 {
	        output = DP-1
            mode = 2560x1440@180
            position = 0x0
            scale = 1
            transform = 0
            vrr = 2
            sdr_min_luminance = 0.005
            sdr_max_luminance = 203
            min_luminance = 0.005
            max_luminance = 1156
            max_avg_luminance = 1156
            bitdepth = 8
            cm = srgb
          }

          monitorv2 {
            output = DP-2
            mode = 1920x1080@144
            position = 2560x250
            scale = 1
            transform = 0
            vrr = 0
            bitdepth = 10
            cm = srgb
          }

          monitor = DP-3, disable
          monitor = HDMI-A-1, disable
	    '';
	  };
	  ".config/hypr/hm/displays/tv.conf" = {
	    text = ''
	      monitorv2 {
	        output = DP-3
	        mode = 3840x2160@120
	        position = 0x0
	        scale = 1
	        transform = 0
	        vrr = 2
	        sdr_min_luminance = 0.005
	        sdr_max_luminance = 203
	        min_luminance = 0.005
	        max_luminance = 1300
	        max_avg_luminance = 1300
	        bitdepth = 10
	        cm = srgb
	      }
	      monitor = DP-1, disable
	      monitor = DP-2, disable
	      monitor = HDMI-A-1, disable
	    '';
	  };
    };
}
