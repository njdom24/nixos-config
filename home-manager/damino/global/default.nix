
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
      outputs.overlays.stable-packages
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
      # DXVK_CONFIG="dxgi.syncInterval = 1" # DXVK equivalent for MESA_VK_WSI_PRESENT_MODE=fifo. GPU-agnostic, but only works on DXVK/VKD3D-Proton games
      vblank_mode = "3"; # Force OpenGL Vsync (Mesa). NV equivalent is __GL_SYNC_TO_VBLANK=1, or consider LD_PRELOAD for MangoHud (details in MangoHud block)
      GSK_RENDERER = "ngl"; # https://bbs.archlinux.org/viewtopic.php?id=299488; Wait for https://github.com/flightlessmango/MangoHud/issues/1305#issuecomment-2706502698 to make it into a release (above 0.8.1)
      LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${pkgs.xorg.libX11}/lib"; # Fixed MangoHud for Wayland apps: https://github.com/ValveSoftware/gamescope/pull/1666 https://github.com/flightlessmango/MangoHud/issues/1497
    };

    file =
    let sunshine-login = pkgs.writeShellScript "sunshine-login" ''
      if [ -f /tmp/sunshine_login ] && [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
        if ${pkgs.gawk}/bin/awk '
        /CLIENT CONNECTED/ {e=1}
        e && /CLIENT DISCONNECTED/ {cancel=1}
        END { if (e && !cancel) exit 0; else exit 1 }
        ' <(${pkgs.gnused}/bin/sed ':a;N;$!ba;s/\n/ /g' /tmp/sunshine_login); then
          # Disable RGB
          ${pkgs.openrgb}/bin/openrgb --mode static --color 000000

          # Assume DP-3 is a dummy display used for headless
          DUMMY="DP-3"
          
          ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$DUMMY".enable
          
          output=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -o)
          
          # Extract the names of the connected displays
          displays=$(echo "$output" | ${pkgs.gawk}/bin/awk '/Output:/ { print $3 }')
          echo "Displays found: $displays"

          # Check if the dummy display is present
          echo "$displays" | grep -qx "$DUMMY"
          if [ $? -ne 0 ]; then
            echo "$DUMMY is not connected."
          fi
          
          # Loop through each display and disable all except DP-3
          while read -r display; do
            if [[ "$display" != "$DUMMY" ]]; then
              echo "Disabling display: $display"
              ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output."$display".disable
            fi
          done <<< "$displays"

          systemctl --user start sunshine
        else
          # Get all connected and enabled outputs
          outputs=($(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j | ${pkgs.jq}/bin/jq -r '
            .outputs[]
            | select(.connected == true and .enabled == true)
            | .name
          '))
          
          len=''${#outputs[@]}
          first=''${outputs[0]:-}
          
          if [[ $len -eq 1 && "$first" == "DP-3" ]]; then
            echo "Only DP-3 is enabled and connected. Restoring..."
            $kscreen_doctor output.DP-1.enable
            $kscreen_doctor output.DP-2.enable
            $kscreen_doctor output.DP-3.disable
          else
            echo "DP-3 is not the only enabled connected output"
          fi
        fi
      fi
    '';
    in {
      ".face.icon".source = ./.face.icon;
      ".config/autostart/sunshine-remote.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Exec=${sunshine-login}
          Hidden=false
          NoDisplay=true
          X-GNOME-Autostart-enabled=true
          Name=My Script
          Comment=Checks for remote login and starts sunshine
        '';
    };

    packages = with pkgs; [
      nwg-look
      nwg-displays
      fluent-gtk-theme
      stable.fluent-icon-theme
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

  	micro = {
  	  enable = true;
  	  settings.clipboard = "external";
  	};

	mangohud = {
	  enable = true;
	  # package = pkgs.legacy.mangohud;
	  enableSessionWide = true;
	  # Consider LD_PRELOAD = "${pkgs.mangohud}/lib/mangohud/libMangoHud.so" for global OpenGL
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
      package = pkgs.xcursor-pro;
    };
    font = {
      name = "Inter";
      package = pkgs.inter;
      size = 10;
    };

    gtk2.force = true;
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
