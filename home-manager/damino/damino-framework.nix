{ inputs, pkgs, lib, ... }: {
	imports = [ ./global ];

	wayland.windowManager = {
	  # eGPU setup
	  sway.extraSessionCommands = ''
	    export WLR_DRM_DEVICES=$XDG_RUNTIME_DIR/dri/dgpu0:$XDG_RUNTIME_DIR/dri/igpu
	  '';

	  hyprland = {
	    extraConfig = ''
	      hl.env("AQ_DRM_DEVICES", xdgRuntimeDir .. "/dri/dgpu0:" .. xdgRuntimeDir .. "/dri/igpu")

	      hl.monitor({
	        output   = "eDP-1",
	        mode     = "2256x1504@59.999",
	        position = "0x0",
	        scale    = 1.175,
	        cm       = "srgb",
	        sdr_eotf = "auto",
	      })
	      hl.monitor({
	        output   = "",
	        mode     = "preferred",
	        position = "auto",
	        scale    = 1,
	        mirror   = "eDP-1",
	      })
	    '';
	  };
	};

	programs = {
	  rofi.yoffset = 11;
	  waybar.settings.mainBar.modules-right = [ "battery" ];
	};

	services = {
	  swaync.settings.positionX = lib.mkForce "right";
	  kanshi.settings = [
	  	{
	  	  profile = {
	  	  	name = "standalone";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "eDP-1";
	  	  	  	status = "enable";
	  	  	  	mode = "2256x1504@59.999Hz";
	  	  	  	position = "0,0";
	  	  	  	scale = 1.175;
	  	  	  }
	  	  	];
	  	  	exec = [
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3.3 output:analog-stereo+input:analog-stereo"
	  	  	];
	  	  };
	  	}
	  	{
	  	  profile = {
	  	  	name = "docked";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "eDP-1";
	  	  	  	status = "enable";
	  	  	  	mode = "2256x1504@59.999Hz";
	  	  	  	position = "0,500";
	  	  	  	scale = 1.25;
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75Hz";
	  	  	    position = "1805,0";
	  	  	    scale = 0.875;
	  	  	  }
	  	  	];
	  	  	exec = [
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3.3 output:hdmi-stereo+input:analog-stereo"
	  	  	];
	  	  };
	  	}
	  	{
	  	  profile = {
	  	  	name = "docked-dual";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "eDP-1";
	  	  	  	status = "disable";
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75Hz";
	  	  	    position = "1920,0";
	  	  	    scale = 0.875;
	  	  	  }
	  	  	  {
	  	  	  	criteria = "AOC 24G1WG4 0x00042EBB";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@60Hz";
	  	  	    position = "0,200";
	  	  	  }
	  	  	];
	  	  	exec = [
              "sh -c '${pkgs.sway}/bin/swaymsg output \"*\" scale_filter smart'"
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3 pro-audio"
	  	  	];
	  	  };
	  	}
	  	# eGPU hybrid
	  	{
	  	  profile = {
	  	  	name = "docked-dual-egpu";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "eDP-1";
	  	  	  	status = "disable";
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75Hz";
	  	  	    position = "0,0";
	  	  	    scale = 0.75;
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@144Hz";
	  	  	    position = "2560,0";
	  	  	  }
	  	  	];
	  	  	exec = [
              "sh -c '${pkgs.sway}/bin/swaymsg output \"*\" scale_filter smart'"
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3 pro-audio"
	  	  	];
	  	  };
	  	}
	  	# eGPU only
	  	{
	  	  profile = {
	  	  	name = "docked-solo-egpu";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75Hz";
	  	  	    position = "0,0";
	  	  	    scale = 0.75;
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@144Hz";
	  	  	    position = "2560,0";
	  	  	  }
	  	  	];
	  	  	exec = [
	  	  	  "sh -c '${pkgs.sway}/bin/swaymsg output \"*\" scale_filter smart'"
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3 pro-audio"
	  	  	];
	  	  };
	  	}
	  	{
	  	  profile = {
	  	  	name = "temp";
	  	  	outputs = [
	  	  	  {
	  	  	  	criteria = "eDP-1";
	  	  	  	status = "disable";
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75Hz";
	  	  	    position = "0,0";
	  	  	    scale = 0.9;
	  	  	  }
	  	  	  {
	  	  	  	criteria = "Xiaomi Corporation Mi Monitor 5745300000795";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@119.998Hz";
	  	  	    position = "2133,0";
	  	  	  }
	  	  	];
	  	  	exec = [
              "sh -c '${pkgs.sway}/bin/swaymsg output \"*\" scale_filter smart'"
	  	  	  "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_00_1f.3 pro-audio"
	  	  	];
	  	  };
	  	}
	  ];
	};
}
