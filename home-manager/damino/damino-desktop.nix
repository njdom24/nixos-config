{ inputs, pkgs, lib, ... }: {
	imports = [ ./global ];

	wayland.windowManager = {
	  sway.extraSessionCommands = ''
	    export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0
	  '';

	  hyprland = {
        extraConfig = ''
          hl.env("AQ_DRM_DEVICES", xdgRuntimeDir .. "/dri/dgpu0")
          hl.monitor({
          	output   = "",
          	mode     = "preferred",
          	position = "auto",
          	scale    = 1,
          	mirror   = "DP-1",
          })
        '';
	  };
	};

	programs = {
	  rofi.yoffset = 24;

	  noctalia.settings = {
	    notifications = lib.mkDefault {
	      monitors = [ "DP-2" ];
	      position = "top_left";
	    };
	  };
	};

	services = {
	  kanshi.settings = [
	    {
	      profile = {
	        name = "desktop-headless";
	        outputs = [
	          {
	            criteria = "Beihai Century Joint Innovation Technology Co.,Ltd P275MV PLUS *";
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
	          "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
	          "${pkgs.sway}/bin/swaymsg output HDMI-A-1 disable"
	          "${pkgs.sway}/bin/swaymsg output DP-3 disable"
	          "${pkgs.sway}/bin/swaymsg output DP-1 hdr on"
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
	          "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
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
	  	      "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      "${pkgs.sway}/bin/swaymsg output DP-1 hdr on"
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
	  	  	    criteria = "Technical Concepts Ltd 55R635 *";
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
	  	      "${pkgs.xrandr}/bin/xrandr --output DP-1 --primary"
	  	      "${pkgs.sway}/bin/swaymsg output DP-1 hdr on"
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
	  ".config/hypr/displays.lua" = {
	    text = ''
	      hl.monitor({
	          output            = "DP-1",
	          mode              = "3840x2160@160",
	          position          = "0x0",
	          scale             = 1.5,
	          transform         = 0,
	          vrr               = 2,
	          bitdepth          = 10,
	          cm                = "hdr",
	          sdr_eotf          = "auto",
	          supports_hdr      = true,
	          sdr_min_luminance = 0.0,
	          sdr_max_luminance = 203,
	          min_luminance     = 0,
	          max_luminance     = 1300,
	          max_avg_luminance = 1300,
	      })

	      hl.monitor({
	          output              = "DP-2",
	          mode                = "1920x1080@144",
	          position            = "2560x250",
	          scale               = 1,
	          transform           = 0,
	          vrr                 = 0,
	          bitdepth            = 10,
	          cm                  = "srgb",
	          sdr_eotf            = "auto",
	          supports_hdr        = false,
	          supports_wide_color = false,
	      })

	      hl.monitor({
	          output            = "HDMI-A-1",
	          disabled          = true,
	          mode              = "3840x2160@120",
	          position          = "4480x0",
	          scale             = 1.5,
	          transform         = 0,
	          vrr               = 0,
	          bitdepth          = 10,
	          cm                = "srgb",
	          sdr_eotf          = "auto",
	          supports_hdr      = true,
	          sdr_min_luminance = 0.0,
	          sdr_max_luminance = 203,
	          min_luminance     = 0,
	          max_luminance     = 1600,
	          max_avg_luminance = 1600,
	      })

	      hl.monitor({
	          output            = "DP-3",
	          disabled          = true,
	          mode              = "3840x2160@120",
	          position          = "4480x0",
	          scale             = 1.5,
	          transform         = 0,
	          vrr               = 2,
	          bitdepth          = 10,
	          cm                = "srgb",
	          sdr_eotf          = "auto",
	          supports_hdr      = true,
	          sdr_min_luminance = 0.0,
	          sdr_max_luminance = 203,
	          min_luminance     = 0,
	          max_luminance     = 1000,
	          max_avg_luminance = 1000,
	      })

	      -- Bodge to fix refresh rate being 144 on first login
	      hl.timer(function()
	        local m = hl.get_monitor("DP-1")
	        if m and m.refresh_rate < 159 then
	            hl.exec_cmd([[hyprctl eval 'hl.monitor({ output = "DP-1", mode = "3840x2160@120" })' &&
	                          hyprctl eval 'hl.monitor({ output = "DP-1", mode = "3840x2160@160" })']])
	        end
	      end, { timeout = 500, type = "oneshot" })
	    '';
	  };
    };
}
