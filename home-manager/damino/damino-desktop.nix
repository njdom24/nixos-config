{ inputs, pkgs, ... }: {
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
	  	  	    criteria = "Technical Concepts Ltd 55R635 Unknown";
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
	  ];

	  mako.output = "DP-2";	
	};
}
