{ inputs, outputs, config, pkgs, lib, ... }: {
  nixpkgs.overlays = [
    # wlroots currently broken, possibly from: https://github.com/nix-community/nixpkgs-wayland/pull/433
  	# inputs.nixpkgs-wayland.overlay
  	outputs.overlays.unstable-packages
  ];

  environment.systemPackages = with pkgs; [
    kitty
    wayland
    xdg-utils # for opening default programs when clicking links
    glib # gsettings
    dracula-theme # gtk theme
    adwaita-icon-theme  # default gnome cursors
    gnome-tweaks
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
    vulkan-validation-layers # for WLR_RENDERER=vulkan
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

  #services.displayManager.setupCommands = "eval $(gnome-keyring-daemon --start --daemonize --components=pkcs11,secrets,ssh)";
  services.displayManager.defaultSession = "sway";

  # enable sway window manager
  programs.sway = {
    enable = true;
    # Workaround
    # Currently not working until below is merged
    #package = (pkgs.swayfx.overrideAttrs (old: { passthru.providedSessions = [ "sway" ]; }));
    wrapperFeatures.gtk = true;
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
