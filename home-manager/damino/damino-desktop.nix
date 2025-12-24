{ inputs, pkgs, lib, ... }: {
	imports = [ ./global ];

	wayland.windowManager = {
	  sway.extraSessionCommands = ''
	    export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0
	  '';

	  hyprland = {
        settings = {
          env = [ "AQ_DRM_DEVICES,$XDG_RUNTIME_DIR/dri/dgpu0" ];
        };
        extraConfig = ''
          monitor = , preferred, auto, 1, mirror, DP-1
        '';
	  };
	};

	programs = {
	  rofi.yoffset = 24;
	};

	services = {
	  kanshi.settings = [
	    {
	      profile = {
	        name = "desktop-headless";
	        outputs = [
	          {
	            criteria = "Beihai Century Joint Innovation Technology Co.,Ltd P275MV PLUS 0000000000000";
	      	    status = "enable";
	      	    mode = "3840x2160@160Hz";
	      	    position = "0,0";
	      	    scale = 1.5;
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
	      	    status = "enable"; # Sway breaks when disabled as of Oct 2025. Worked around below...
	      	    adaptiveSync = false;
	      	  }
	        ];
	        exec = [
	          #"sh -c '${pkgs.sway}/bin/swaymsg output \"*\" render_bit_depth 10'" # Breaks xdg-desktop-portal-wlr/pipewire capture
	          "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	          "${pkgs.sway}/bin/swaymsg output HDMI-A-1 disable"
	          #"${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_03_00.1 pro-audio"
	          #"${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3"
	        ];
	      };
	    }
	    {
	      profile = {
	        name = "desktop";
	        outputs = [
	          {
	            criteria = "Beihai Century Joint Innovation Technology Co.,Ltd P275MV PLUS 0000000000000";
	      	    status = "enable";
	      	    mode = "3840x2160@160Hz";
	      	    position = "0,0";
	      	    scale = 1.5;
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
	  	    name = "desktop-secondary";
	  	    outputs = [
	  	      {
	  	        criteria = "AOC Q27G40XMN 0x00000081";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
	      	    position = "2560,0";
	      	    #adaptiveSync = true;
	      	  }
	  	      {
	  	        criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@143.999Hz";
	  	  	    position = "0,0";
	  	  	    #position = "2560,0";
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	  	  {
	  	  	    criteria = "Technical Concepts Ltd 55R635 0x5BED4FBA";
	  	  	    status = "disable";
	  	  	    mode = "2560x1440@120Hz";
	  	  	    position = "5120,0";
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	    ];
	  	    exec = [
	  	      "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      #"${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_0c_00.1 pro-audio"
	  	      #"${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_0c_00.1.pro-output-9"
	  	    ];
	  	  };
	  	}
	  	{
	  	  profile = {
	  	    name = "desktop-secondary-headless";
	  	    outputs = [
	  	      {
	  	        criteria = "AOC Q27G40XMN 0x00000081";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
	      	    position = "2560,0";
	      	    #adaptiveSync = true;
	      	  }
	  	      {
	  	        criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@143.999Hz";
	  	  	    position = "0,0";
	  	  	    #position = "2560,0";
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	  	  {
	  	  	    criteria = "Technical Concepts Ltd 55R635 0x5BED4FBA";
	  	  	    status = "disable";
	  	  	    mode = "2560x1440@120Hz";
	  	  	    position = "5120,0";
	  	  	    #adaptiveSync = true;
	  	  	  }
	  	  	  {
	  	  	    criteria = "Samsung Electric Company SAMSUNG 0x01000E00"; # Dummy display
	  	  	    status = "disable";
	  	  	    adaptiveSync = false;
	  	  	  }
	  	    ];
	  	    exec = [
	  	      "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      #"${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_0c_00.1 pro-audio"
	  	      #"${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_0c_00.1.pro-output-9"
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
            mode = 3840x2160@160
            position = 0x0
            scale = 1.5
            transform = 0
            vrr = 2
            supports_hdr = 1
            sdr_min_luminance = 0.005
            sdr_max_luminance = 260
            min_luminance = 0.005
            max_luminance = 1156
            max_avg_luminance = 1156
            bitdepth = 10
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

          # Bodge to fix refresh rate being 144 on first login
          exec-once=sleep 1 && hyprctl keyword "monitorv2[DP-1]:mode" 3840x2160@160
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
	        supports_hdr = 1
	        sdr_min_luminance = 0.005
	        sdr_max_luminance = 260
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
