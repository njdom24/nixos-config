{ inputs, pkgs, lib, ... }: {
	imports = [ ./global ];

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
	            criteria = "AOC Q27G40XMN 2QTR1JA000129";
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
	      	    adaptiveSync = true;
	      	  }
	        ];
	        exec = [
	          #"sh -c '${pkgs.sway}/bin/swaymsg output \"*\" render_bit_depth 10'" # Breaks xdg-desktop-portal-wlr/pipewire capture
	          "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	          "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_03_00.1 pro-audio"
	          "${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3"
	        ];
	      };
	    }
	    {
	      profile = {
	        name = "desktop-legacy";
	        outputs = [
	          {
	            criteria = "Xiaomi Corporation Mi Monitor 5745300000795";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
	      	    position = "0,0";
	      	    adaptiveSync = true;
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
	      	    adaptiveSync = true;
	      	  }
	        ];
	        exec = [
	          #"sh -c '${pkgs.sway}/bin/swaymsg output \"*\" render_bit_depth 10'" # Breaks xdg-desktop-portal-wlr/pipewire capture
	          "${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --primary"
	          "${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_03_00.1 pro-audio"
	          "${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_03_00.1.pro-output-3"
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
	  	    name = "desktop-secondary";
	  	    outputs = [
	  	      {
	  	        criteria = "Acer Technologies VG271U 0x0302811A";
	  	  	    status = "enable";
	  	  	    mode = "2560x1440@143.999Hz";
	  	  	    position = "2560,0";
	  	  	    adaptiveSync = true;
	  	  	  }
	  	      {
	  	  	    criteria = "Samsung Electric Company LC27T55 HCPW203589";
	  	  	    status = "enable";
	  	  	    mode = "1920x1080@75";
	  	  	    position = "0,0";
	  	  	    scale = 0.75;
	  	  	    adaptiveSync = true;
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
}
