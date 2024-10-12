{ inputs, pkgs, ... }: {
	imports = [ ./global ];
	wayland.windowManager.sway.extraConfig = ''
	  exec ${ pkgs.writeShellScript "check_wifi" ''
	  #! /usr/bin/env bash

	  if [ "$(ip a | grep eth0 | grep UP)" ]; then
	    ${pkgs.iwd}/bin/iwctl device wlan0 set-property Powered off
	  else
	    ${pkgs.iwd}/bin/iwctl device wlan0 set-property Powered on
	    exec ${pkgs.iwgtk}/bin/iwgtk -i
	  fi
	  ''}
	'';

	programs = {
	  rofi.yoffset = 11;
	  waybar.settings.mainBar.modules-right = [ "battery" ];
	};

	services = {
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
	  	  	  	scale = 1.25;
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
	  ];
	};
}
