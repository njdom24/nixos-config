
# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  hostName,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    inputs.nix-colors.homeManagerModules.default
    ./../../common/zsh
    ./sway.nix
    ./kitty.nix
    ./theming
  ];

  colorScheme = inputs.nix-colors.colorSchemes.mocha;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.legacy-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      input-fonts.acceptLicense = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # Unsure if needed
  #nix = {
  #  package = lib.mkDefault pkgs.nix;
  #  settings = {
  #    experimental-features = [ "nix-command" "flakes" ];
  #    #warn-dirty = false;
  #  };
  #};

  home = {
    username = "damino";
    homeDirectory = "/home/damino";
    sessionPath = [ "$HOME/.local/bin" ];
    sessionVariables = {
      # GTK_THEME= "${config.gtk.theme.name}:dark";
      MESA_VK_WSI_PRESENT_MODE = "fifo"; # MangoHud vsync is non-functional as of 24.11; https://gitlab.freedesktop.org/mesa/mesa/-/issues/11379
      RADV_PERFTEST = "nggc"; # https://www.phoronix.com/news/Mesa-24.3-NGG-Culling-RDNA1; redundant in 25.05
      GSK_RENDERER = "ngl"; # https://bbs.archlinux.org/viewtopic.php?id=299488; probably fixed by 25.05
      LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${pkgs.xorg.libX11}/lib"; # Fixed MangoHud for Wayland apps: https://github.com/flightlessmango/MangoHud/issues/1497
    };

    file = {
      ".face.icon".source = ./.face.icon;
    };

    packages = with pkgs; [
      nwg-look
      nwg-displays
      fluent-gtk-theme
      fluent-icon-theme
      kora-icon-theme
      flavours
      gradience
      adw-gtk3
    ];
  };

  # Enable home-manager and git
  programs = {
    home-manager.enable = true;
  	git = {
  	  enable = true;
  	  package = pkgs.gitFull;
  	  extraConfig = {
  	    safe.directory = "/etc/nixos";
  	  	credential.helper = "libsecret";
  	  };
  	  userName = "Damino";
  	  userEmail = "dom32400@aol.com";
  	};

	mangohud = {
	  enable = true;
	  # package = pkgs.legacy.mangohud;
	  enableSessionWide = true;
	  settings = {
	  	no_display = true;
	  	vsync = 3; # Currently broken due to https://gitlab.freedesktop.org/mesa/mesa/-/issues/11379, set MESA_VK_WSI_PRESENT_MODE=fifo for Mesa instead
 	  	gl_vsync = 1;
	  	gpu_name = true;
	  	fps_limit_method = "early";
	  	toggle_hud = "Shift_R+F12";
	  	toggle_logging = "Shift_L+Shift_R+F1+F2+F3+F4+F5+F6+F7+F8+F9"; # Unbind
	  	reload_cfg = "Shift_L+Shift_R+F1+F2+F3+F4+F5+F6+F7+F8+F9"; # Unbind
	  	blacklist = ".gamescope-wrapped,gamescope,gamescope-wl";
	  };
	};
  };

  services = {
  	syncthing.enable = true;
  	arrpc.enable = true;
  	gammastep = {
  	  enable = true;
  	  provider = "manual";
  	  latitude = 40.0;
  	  longitude = 74.0;
  	};
  };

  systemd.user = {
    # Nicely reload system units when changing configs
    startServices = "sd-switch";
    services = {
      gammastep.Install.WantedBy = lib.mkForce [ ];
    };
  };

  gtk = let
    commonExtraConfig = {
      gtk-xft-antialias = 1;
      gtk-xft-rgba = "none";
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "slight";
      gtk-decoration-layout = "menu:";
    }; in {
    enable = true;
    theme = {
      name = "Fluent-Dark";
      package = pkgs.fluent-gtk-theme;
    };
    iconTheme = {
      name = "kora";
      package = pkgs.kora-icon-theme;
    };
    cursorTheme = {
      name = "XCursor-Pro-Dark";	
    };
    font = {
      name = "Inter";
      package = pkgs.inter;
      size = 10;
    };

    gtk3.extraConfig = lib.mkMerge [
      commonExtraConfig
      {
        gtk-application-prefer-dark-theme = 1;
      }
    ];
    gtk4.extraConfig = commonExtraConfig;
  };

  # Preferred over setting GTK_THEME, to support runtime changes for Libadwaita GTK4 apps
  xdg.configFile = let
    themePath = "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0";
    darkCssFile = "${themePath}/gtk-dark.css";
    cssFile = if builtins.pathExists darkCssFile && config.gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme == 1
      then darkCssFile
      else "${themePath}/gtk.css";
  in {
    "gtk-4.0/assets".source = "${themePath}/assets";

    # Conditionally include the CSS files only if they exist
    "gtk-4.0/gtk.css".source = cssFile;
    "gtk-4.0/gtk-dark.css".source = pkgs.lib.mkIf (builtins.pathExists darkCssFile) darkCssFile;
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
