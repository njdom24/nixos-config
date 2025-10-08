
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
    ./plasma.nix
    ./sway.nix
    ./hyprland.nix
    ./kitty.nix
    ./theming
    ./gpu-screen-recorder.nix
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
      #GSK_RENDERER = "ngl"; # https://bbs.archlinux.org/viewtopic.php?id=299488; Wait for https://github.com/flightlessmango/MangoHud/issues/1305#issuecomment-2706502698 to make it into a release (above 0.8.1)
      LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${pkgs.xorg.libX11}/lib"; # Fixed MangoHud for Wayland apps: https://github.com/ValveSoftware/gamescope/pull/1666 https://github.com/flightlessmango/MangoHud/issues/1497
    };

    packages = let
      playYoutubeHdr = pkgs.writeShellScriptBin "youtube-hdr" ''
      #!/usr/bin/env bash
      url="$1"

      hdr_format=$(${pkgs.yt-dlp}/bin/yt-dlp -F "$url" | ${pkgs.gnugrep}/bin/grep "HDR" | ${pkgs.coreutils}/bin/tail -n 1 | ${pkgs.gawk}/bin/awk '{print $1}')

      if [[ -z "$hdr_format" ]]; then
        echo "Video has no HDR option." >&2
        exit 1
      fi

      format="''${hdr_format}+bestaudio"
      # "''$()

      echo "Playing HDR: $format"
      ${pkgs.mpv}/bin/mpv --ytdl-format="bestvideo+bestaudio/best" "$url"
    ''; in with pkgs; [
      nwg-look
      nwg-displays
      fluent-gtk-theme
      stable.fluent-icon-theme
      stable.kora-icon-theme
      flavours
      adw-gtk3
      playYoutubeHdr
    ];
  };

  fonts.fontconfig.enable = true;

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
	  	fps_limit = 180;
	  	fps_limit_method = "early";
	  	toggle_hud = "Shift_R+F12";
	  	toggle_logging = "Shift_L+Shift_R+F1+F2+F3+F4+F5+F6+F7+F8+F9"; # Unbind
	  	reload_cfg = "Shift_L+Shift_R+F1+F2+F3+F4+F5+F6+F7+F8+F9"; # Unbind
	  	blacklist = ".gamescope-wrapped,gamescope,gamescope-wl";
	  };
	};

	mpv = {
	  enable = true;
	  config = {
	    profile = "fast";
	    hwdec = "auto-safe";
	  };
	  profiles = {
	    HDR = {
	      profile-cond = "(p[\"video-params/primaries\"] == \"bt.2020\") and (p[\"video-params/gamma\"] == \"pq\")";
	      vo = "gpu-next";
	      target-colorspace-hint = "yes";
	      #tone-mapping = "spline";
	      gamut-mapping-mode = "auto";
	      #hdr-compute-peak = "yes";
	    };
	  };
	};
  };

  services = {
  	syncthing.enable = true;
  	arrpc.enable = true;
  	gammastep = {
  	  enable = true;
  	  provider = "manual";
  	  temperature = {
  	    day = 4500;
  	    night = 4500;
  	  };
  	  latitude = 40.0;
  	  longitude = 74.0;
  	};
  };

  systemd.user = {
    # Nicely reload system units when changing configs
    startServices = "sd-switch";
    services = {
      gammastep.Install.WantedBy = lib.mkForce [ ];
      stable-render-nodes = let
        stable-render-nodes = pkgs.writeShellScript "stable-render-nodes.sh" ''
          #!/usr/bin/env bash          
          outdir="$XDG_RUNTIME_DIR/dri"
          ${pkgs.coreutils}/bin/mkdir -p "$outdir"
          
          declare -A cards renders depths
          
          # Collect cards and record PCI path depth
          for path in /dev/dri/by-path/*-card; do
            pci="''${path##*/}"
            pci="''${pci%-card}"
            cards["$pci"]="$path"
            sysfs=$(${pkgs.systemd}/bin/udevadm info -q path "$path")
            # Count PCI segments (number of '/0000:' occurrences)
            depth=$(${pkgs.gnugrep}/bin/grep -o "0000:" <<<"$sysfs" | ${pkgs.coreutils}/bin/wc -l)
            depths["$pci"]="$depth"
          done
          
          # Collect render nodes
          for path in /dev/dri/by-path/*-render; do
            pci="''${path##*/}"
            pci="''${pci%-render}"
            renders["$pci"]="$path"
          done
          
          # Sort by PCI path depth (ascending)
          sorted=($(for k in "''${!depths[@]}"; do echo "''${depths[$k]} $k"; done | ${pkgs.coreutils}/bin/sort -n | ${pkgs.gawk}/bin/awk '{print $2}'))
          
          i=0
          igpu_assigned=false
          known_dgpus=("Radeon RX" "NVIDIA")

          for pci in "''${sorted[@]}"; do
            pci_id="''${pci#pci-}"
            name="$(${pkgs.pciutils}/bin/lspci -s "$pci_id" | ${pkgs.gnused}/bin/sed -E 's/.*\[(.*)\].*/\1/')"
            depth=''${depths[$pci]}

            could_be_igpu=false
            if [[ $igpu_assigned == false && "$depth" -le 3 ]]; then
              could_be_igpu=true
              for substr in "''${known_dgpus[@]}"; do
                if [[ "$name" == *"$substr"* ]]; then
                  could_be_igpu=false
                  break
                fi
              done
            fi
            
            if [[ "$could_be_igpu" == true ]]; then
              echo "Assigning iGPU: $name (depth=$depth)"
              ${pkgs.coreutils}/bin/ln -sf "''${cards[$pci]}" "$outdir/igpu"
              [[ -n "''${renders[$pci]:-}" ]] && ${pkgs.coreutils}/bin/ln -sf "''${renders[$pci]}" "$outdir/igpu-render"
              igpu_assigned=true
            else
              echo "Assigning dGPU$i: $name (depth=$depth)"
              ${pkgs.coreutils}/bin/ln -sf "''${cards[$pci]}" "$outdir/dgpu$i"
              [[ -n "''${renders[$pci]:-}" ]] && ${pkgs.coreutils}/bin/ln -sf "''${renders[$pci]}" "$outdir/dgpu$i-render"
              ((i++))
            fi
          done
          echo ''$()
          exit 0
        ''; in {
        Unit = {
          Description = "Create stable GPU symlinks for Wayland compositors";
          After = [ "default.target" ];
          Before = [ "graphical-session-pre.target" "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${stable-render-nodes}";
          RemainAfterExit = "yes";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
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
      package = pkgs.stable.kora-icon-theme;
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
