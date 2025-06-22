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
	      	    adaptiveSync = false;
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
	        name = "desktop-headless";
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
	      	    adaptiveSync = false;
	      	  }
	      	  {
	      	    criteria = "Samsung Electric Company Odyssey G8 HCPTB00064"; # Dummy display
	      	    status = "disable";
	      	    adaptiveSync = false;
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
	  	    name = "desktop-secondary-old";
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
	  	{
	  	  profile = {
	  	    name = "desktop-secondary";
	  	    outputs = [
	          {
	            criteria = "Xiaomi Corporation Mi Monitor 5745300000795";
	      	    status = "enable";
	      	    mode = "2560x1440@180Hz";
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

	home.file =
	let plasma-display-restore = pkgs.writeShellScript "plasma-display-restore" ''
	  if [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
	    outputs=($(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o | ${pkgs.colorized-logs}/bin/ansi2txt | ${pkgs.gawk}/bin/awk '
	      /^Output:/ {
	        if (in_block && enabled && connected)
	          print name
	        name = $3
	        enabled = 0
	        connected = 0
	        in_block = 1
	        next
	      }
	      /enabled/ { enabled = 1 }
	      /connected/ { connected = 1 }
	      END {
	        if (in_block && enabled && connected)
	          print name
	      }
	    '))
	    
	    len=$(echo "''${outputs[@]}" | wc -w)
	    first=$(echo "''${outputs[@]}" | awk '{print $1}')
	    
	    if [[ $len -eq 1 && "$first" == "DP-3" ]]; then
	      echo "Only DP-3 is enabled and connected. Restoring..."
	      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.enable
	      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-2.enable
	      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-3.disable
	    else
	      echo "DP-3 is not the only enabled connected output"
	    fi
	    
	  fi
	'';
	in {
	  ".config/autostart/plasma-display-restore.desktop".text = ''
	      [Desktop Entry]
	      Type=Application
	      Exec=${plasma-display-restore}
	      Hidden=false
	      NoDisplay=true
	      X-GNOME-Autostart-enabled=true
	      Name=My Script
	      Comment=Checks for previous Sunshine display config and restores to desktop usability
	    '';
	};
}
