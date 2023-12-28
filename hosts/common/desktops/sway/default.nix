{ inputs, config, pkgs, lib, ... }:

let
  # Might not be working
  config = {
  	security.wrappers = {
  	  swayfx = {
  	  	source = "${pkgs.swayfx}/bin/sway";
	  	capabilities = "cap_sys_nice+ep";
 	  };
 	  sway = {
 	    source = "${pkgs.sway}/bin/sway";
 	  	capabilities = "cap_sys_nice+ep";
	  }; 	  
  	};
  	security.pam.loginLimits = [
  	  { domain = "@users"; item = "rtprio"; type = "-"; value = 1; }
  	];
  	
  };

in
{
  nixpkgs.overlays = [
    # wlroots currently broken, possibly from: https://github.com/nix-community/nixpkgs-wayland/pull/433
  	# inputs.nixpkgs-wayland.overlay
  ];

  environment.systemPackages = with pkgs; [
    kitty
    wayland
    xdg-utils # for opening default programs when clicking links
    glib # gsettings
    dracula-theme # gtk theme
    gnome3.adwaita-icon-theme  # default gnome cursors
    gnome.gnome-tweaks
    swaylock
    swayidle
    grim # screenshot functionality
    slurp # screenshot functionality
    wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    bemenu # wayland clone of dmenu
    mako # notification system developed by swaywm maintainer
    #nwg-displays # tool to configure displays
    #nwg-look # doesn't work system-level
    nwg-menu
    waybar
    rofi-wayland
    lxappearance
    wdisplays
    kanshi
    jq
  ];

  # xdg-desktop-portal works by exposing a series of D-Bus interfaces
  # known as portals under a well-known name
  # (org.freedesktop.portal.Desktop) and object path
  # (/org/freedesktop/portal/desktop).
  # The portal interfaces include APIs for file access, opening URIs,
  # printing and others.
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # gtk portal needed to make gtk apps happy
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  #services.xserver.displayManager.setupCommands = "eval $(gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)";
  services.xserver.displayManager.defaultSession = "sway";

  # enable sway window manager
  programs.sway = {
    enable = true;
    # Workaround
    # Currently not working until below is merged
    #package = (pkgs.swayfx.overrideAttrs (old: { passthru.providedSessions = [ "sway" ]; }));
    wrapperFeatures.gtk = true;

	
    extraSessionCommands = ''
    export SDL_VIDEODRIVER=wayland
    export QT_QPA_PLATFORM=wayland
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    export _JAVA_AWT_WM_NONREPARENTING=1
    export MOZ_ENABLE_WAYLAND=1
    export MOZ_DBUS_REMOTE=1
    export XDG_CURRENT_DESKTOP=sway
    export NIXOS_OZONE_WL=1

    export REMOTE_ENABLED=$(pgrep -x x11vnc > /dev/null && echo 1 || echo 0)
    export WLR_NO_HARDWARE_CURSORS=$REMOTE_ENABLED
    export WLR_BACKENDS=$([ $REMOTE_ENABLED = 1 ] && echo "headless,libinput" || echo "drm,libinput")
    
    eval $(gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)
    export SSH_AUTH_SOCK
    '';

    extraOptions = [
      "--unsupported-gpu"	
    ];
    # Consider export QT_QPA_PLATFORMTHEME=qt5ct
  };

  # Enable when this is merged: https://github.com/NixOS/nixpkgs/pull/267261
  #programs.sway.package = pkgs.sway.override {
    #sway-unwrapped = pkgs.swayfx;
    #extraSessionCommands = ''
    #extraOptions = programs.sway.extraOptions;
    #withBaseWrapper = programs.sway.wrapperFeatures.base;
    #withGtkWrapper = programs.sway.wrapperFeatures.gtk;
  #};

  
}
