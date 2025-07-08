# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, outputs, config, lib, pkgs, ... }:
let
  # Gamescope helper to auto-fill mode
  gsc = pkgs.writeShellScriptBin "gsc" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Resolution & refresh detection
    get_display_mode() {
      if [ -n "''${SWAYSOCK-}" ]; then #"'''
        swaymsg -t get_outputs | jq -r '
          .[] | select(.focused) | "\(.current_mode.width) \(.current_mode.height) \(.current_mode.refresh / 1000)"
        '
      elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        read width height refresh < <(
          kscreen-doctor -j | jq -r '
            (.outputs | map(select(.enabled == true)) | sort_by(.priority))[0] as $out |
            ($out.currentModeId) as $curId |
            ($out.modes[] | select(.id == $curId)) |
            "\(.size.width) \(.size.height) \(.refreshRate)"
          '
        )
        
        echo "$width $height $refresh"
      fi
    }

    get_hdr() {
      if [ -n "''${SWAYSOCK-}" ]; then #"'''
        echo "0"
      elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        json=$(${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor -j)
        mapfile -t enabled < <(${pkgs.jq}/bin/jq -r '.outputs[] | select(.connected and .enabled and has("hdr") and .hdr == true) | .name' <<< "$json")
        ''$() # Fix syntax highlighting
        if [ ''${#enabled[@]} -eq 0 ]; then
          echo "0"
        else
          echo "1"
        fi
      else
        echo "0"
      fi
    }

    hdr_enabled="$(get_hdr)"

    # Try to enable/disable RenoDX HDR ReShade automatically
    if [[ -v RENODX_HDR && "$RENODX_HDR" == "1" ]]; then
      reshade_file="$(${pkgs.coreutils}/bin/timeout 5 ${pkgs.findutils}/bin/find "$PWD" -type f -name 'ReShade.ini' | ${pkgs.coreutils}/bin/head -n 1)"

      if [[ -n "$reshade_file" ]]; then
        reshade_dir="$(dirname "$reshade_file")"
        # Find matching .addon64 file containing 'renodx'
        addon_file="$(${pkgs.findutils}/bin/find "$reshade_dir" -maxdepth 1 -type f -name '*.addon64' -printf '%f\n' | ${pkgs.gnugrep}/bin/grep renodx | head -n1)"
        addon_id="RenoDX@$addon_file"
        
        # Read current DisabledAddons value from [ADDON] section
        current=$(${pkgs.gawk}/bin/awk -F= '/^\[ADDON\]/{f=1} f && /^DisabledAddons=/{print substr($0, index($0,$2)) ; exit}' "$reshade_file" | ${pkgs.coreutils}/bin/tr -d '\r\n' | ${pkgs.gnused}/bin/sed 's/^,*//; s/,*$//; s/ //g')
        # Helper function
        contains() {
          [[ ",$1," == *",$2,"* ]]
        }
        
        if [[ "$hdr_enabled" == "0" ]]; then
          # Append addon_id if missing
          if ! contains "$current" "$addon_id"; then
            if [[ -z "$current" ]]; then
              new_disabled_addons="$addon_id"
            else
              new_disabled_addons="$current,$addon_id"
            fi
          fi
        elif [[ "$hdr_enabled" == "1" ]]; then
          # Remove addon_id if present
          if contains "$current" "$addon_id"; then
            # Filter the addon_id from the list
            IFS=',' read -ra arr <<< "$current"
            new_arr=()
            for addon in "''${arr[@]}"; do
              if [[ "$addon" != "$addon_id" && -n "$addon" ]]; then
                new_arr+=("$addon")
              fi
            done
            new_disabled_addons=$(IFS=, ; echo "''${new_arr[*]}")
          fi
        fi

        if [[ -v new_disabled_addons ]]; then
          temp_file="$(${pkgs.mktemp}/bin/mktemp)"

          # Update the INI file DisabledAddons= line inside [ADDON]
          ${pkgs.gawk}/bin/awk -v new="$new_disabled_addons" '
          BEGIN{in_addon=0}
           /^\[ADDON\]/ {in_addon=1; print; next}
           /^\[/ && !/^\[ADDON\]/ {in_addon=0}
           in_addon && /^DisabledAddons=/ {print "DisabledAddons=" new; next}
           {print}
          ' "$reshade_file" > "$temp_file" && mv "$temp_file" "$reshade_file"

          rm "$temp_file"
        fi
      fi
    fi

    read width height refresh <<< "$(get_display_mode || echo "1920 1080 60")"
    refresh=$(echo $refresh | ${pkgs.num-utils}/bin/round)

    if [[ -v MANGOHUD_FPS_LIMIT ]]; then
      fps_limit="$MANGOHUD_FPS_LIMIT"
    else
      fps_limit=""
    fi
    refresh_rate=""
    steam_mode=0

    # Use a loop to walk through the args
    i=0
    while [ $i -lt $# ]; do
      arg="''${@:$((i+1)):1}"
      echo "''$()"
      echo "Looping arg $arg"
    
      # Check for MANGOHUD_CONFIG
      if [[ "$arg" == MANGOHUD_CONFIG=* ]]; then
        config="''${arg#MANGOHUD_CONFIG=}"
        config="''${config#\"}"
        config="''${config%\"}"
    
        IFS=',' read -ra settings <<< "$config"
        for setting in "''${settings[@]}"; do
          if [[ "$setting" == fps_limit=* ]]; then
            fps_limit="''${setting#fps_limit=}"
            break
          fi
        done

      elif [[ "$arg" == MANGOHUD_FPS_LIMIT=* ]]; then
        fps_limit="''${arg#*=}"
        echo '''
      fi

      # Check for gamescope args
      if [[ ! -v scope_vars_done ]]; then
        # Check for -r <value>
        if [[ "$arg" == "-r" ]]; then
          next="''${@:$((i+2)):1}"
          if [[ -n "$next" ]]; then
            refresh_rate="$next"
          fi
          i=$((i+1)) # skip the next one too
        fi

        if [[ "$arg" == "--steam" || "$arg" == "-e" ]]; then
          steam_mode=1
        fi

        if [[ "$arg" == "--" ]]; then
          scope_vars_done=1
        fi
      fi

      i=$((i+1))
    done
    echo "''$()"

    if [[ -n "$refresh_rate" ]]; then
      rate="$refresh_rate"
    elif [[ -n "$fps_limit" ]]; then
      rate="$fps_limit"
    fi

    # Skip wrapping if we're already inside Gamescope. Execute everything after '--'
    if [ "$XDG_CURRENT_DESKTOP" = "gamescope" ]; then
      while [ "$#" -gt 0 ]; do
        if [ "$1" = "--" ]; then
          shift
          #exec "$@"
          if [[ "$hdr_enabled" == "1" ]]; then
            ${pkgs.gamescope}/bin/gamescopectl hdr_enabled 1
          fi
          if [[ -v rate ]]; then
            echo "Setting FPS limit to $rate"
            ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $rate
          fi
          "$@"
          if [[ -v rate ]]; then
            echo "Re-setting FPS limit from $rate to $refresh"
            ${pkgs.gamescope}/bin/gamescopectl debug_set_fps_limit $refresh
          fi
          exit 0
        fi
        shift
      done
    
      echo "Error: '--' not found. No command to run." >&2
      exit 1
    fi

    echo "Limits: $fps_limit,$refresh_rate"

    # Set environment variables
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}='${lib.escapeShellArg v}'") config.programs.gamescope.env)}

    # If MangoHud is enabled, translate to mangoapp
    mangoapp_flag=""
    # Avoid this path for now
    if [[ -v NO_MANGOHUD && "$MANGOHUD" = "1" ]]; then
      mangoapp_flag="--mangoapp"
      
      if [[ -v MANGOHUD_CONFIGFILE && -f "$MANGOHUD_CONFIGFILE" ]]; then
        mangohud_path="$MANGOHUD_CONFIGFILE"
      elif [[ -f "/home/$USER/.config/MangoHud/MangoHud.conf" ]]; then
        mangohud_path="/home/$USER/.config/MangoHud/MangoHud.conf"
      fi

      mangoapp_file="$(${pkgs.mktemp}/bin/mktemp --tmpdir=/home/$USER)" # tmpdir required only for Steam mode since it has unique /tmp (on NixOS?)
      #mangohud_file="$(${pkgs.mktemp}/bin/mktemp --tmpdir=/home/$USER)"

      if [[ -v mangohud_path ]]; then
        ${pkgs.coreutils}/bin/cat "$mangohud_path" > "$mangoapp_file" # Copy current config
        #${pkgs.coreutils}/bin/cat "$mangohud_path" > "$mangohud_file" # Copy current config

        # Remove settings that can affect gamescope's frame pacing (Primarily for Steam mode, but won't hurt in general)
        ${pkgs.gnused}/bin/sed -i '/^blacklist=/d' "$mangoapp_file" # Remove blacklist
        ${pkgs.gnused}/bin/sed -i '/^vsync=/d' "$mangoapp_file" # Remove Vulkan vsync
        ${pkgs.gnused}/bin/sed -i '/^gl_vsync=/d' "$mangoapp_file" # Remove OpenGL vsync
        ${pkgs.gnused}/bin/sed -i '/^fps_limit_method=/d' "$mangoapp_file" # Remove fps limiter method
        ${pkgs.gnused}/bin/sed -i '/^fps_limit=/d' "$mangoapp_file" # Remove fps limiter

        if [[ "$steam_mode" == "1" ]]; then
          # MangoApp's keybinds don't work in Steam mode
          mangoapp_flag=""
        else
          mangoapp_flag="--mangoapp"
          MANGOHUD=0
        fi
        
        #keybind_disable="Shift_L+Shift_R+F1+F2+F3+F4+F5+F6+F7+F8+F9" # MangoHud cannot unset keybinds, so work around
        #keybind_disable="Shift_R+F11" # MangoHud cannot unset keybinds, so work around
        #${pkgs.gnused}/bin/sed -i "s/^toggle_hud=.*/toggle_hud=$keybind_disable/" "$mangohud_file"
        #${pkgs.gnused}/bin/sed -i '/^fps_limit_method=/d' "$mangohud_file" # Fix VRR by removing fps_limit_method(=early)
        #echo "fps_limit_method=late" >> "$mangohud_file"
      fi

      export MANGOHUD_CONFIGFILE="$mangoapp_file"

      #if [[ "$1" == "--" ]]; then
      #  # Remove the leading '--' from the args
      #  shift
      #fi

      #mangoapp_flag="--mangoapp -- env MANGOHUD_CONFIGFILE=$mangohud_file "
      #echo "$mangoapp_flag $@" > /home/damino/test.log
    fi

    echo "Launching gamescope at $width"x"$height@$refresh"

    while true; do
      if gamescope ${
        lib.concatMapStringsSep " " (arg: lib.escapeShellArgs (lib.splitString " " arg))
        config.programs.gamescope.args
      } -r "$refresh" -W "$width" -H "$height" $mangoapp_flag "$@"; then
      #} -r "''${rate:-$refresh}" -W "$width" -H "$height" $mangoapp_flag "$@"; then
        #echo "''$()"
        break
      elif [[ "$steam_mode" == "1" ]]; then
        break
      else
        code=$?
        if [[ "$code" -eq 143 || "$code" -eq 137 ]]; then
          echo "gamescope exited normally"
          break
        fi
        echo "gamescope exited with code $code, retrying in 1 second..."
        sleep 1
      fi
    done

    rm -f "$mangoapp_file"
    #rm -f "$mangohud_file"
  '';
in 
{
  imports =
    [
      inputs.chaotic.nixosModules.default
    ] ++ (builtins.attrValues outputs.nixosModules);

  nixpkgs.overlays = [
  	outputs.overlays.unstable-packages
  	outputs.overlays.legacy-packages
  	outputs.overlays.additions
  	outputs.overlays.modifications
  ];

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server	
	  #extest.enable = true; # Breaks when Steam is run through gamescope. Alternatively needs https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
      package = pkgs.steam.override {
        
        extraProfile = ''
          # https://github.com/NixOS/nixpkgs/issues/279893
          unset TZ
          if [ -n "$SWAYSOCK" ]; then
            if echo "$WAYLAND_DISPLAY" | ${pkgs.gnugrep}/bin/grep "gamescope" >/dev/null 2>&1 || pgrep "gamescope" > /dev/null; then
              # Launched through gamescope. Could enable after https://github.com/Supreeeme/extest/issues/11 or portal issue below
              echo "Disabling Extest"
            else
              # Needed until https://github.com/emersion/xdg-desktop-portal-wlr/issues/278
              export LD_PRELOAD="$LD_PRELOAD:${pkgs.pkgsi686Linux.extest}/lib/libextest.so"
              echo "Enabling Extest"
            fi
          fi
        '';
        # https://github.com/NixOS/nixpkgs/issues/271483
        extraLibraries = pkgs: [ pkgs.pkgsi686Linux.gperftools ];
      };

      extraPackages = with pkgs; [
        gamescope
        gamescope-wsi
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
        # Where gamescope-session looks for "Exit to Desktop" when -steamos3 is provided
        (writeShellScriptBin "steamos-session-select" ''
            /usr/bin/env steam -shutdown
        '')
        (writeScriptBin "steamos-polkit-helpers/steamos-update" ''
          #!${pkgs.stdenv.shell}
          exit 7
        '')
      ];

      extraCompatPackages = with pkgs; [
        gamescope-wsi
        vulkan-loader
      ];

      gamescopeSession = {
        enable = true;
        env = {
          #MANGOHUD = "0";
          #MANGOHUD_CONFIG = "read_cfg,no_display";
          #MANGOHUD_CONFIGFILE="~/.config/MangoHud/MangoHud.conf";
          #VK_LOADER_LAYERS_DISABLE = "VK_LAYER_MANGOHUD_overlay_64_x86_64,VK_LAYER_MANGOHUD_overlay_32_x86";
          #WLR_RENDERER = "vulkan";
          DXVK_HDR = "1"; # Works with VKD3D-Proton, confirmed required as of Proton 9.0-3
          ENABLE_GAMESCOPE_WSI = "1";
          ENABLE_HDR_WSI = "0";
          STEAM_MULTIPLE_XWAYLANDS = "1";
          PROTON_ENABLE_AMD_AGS = "1";
        };
        args = [
          "-f"
          "--xwayland-count 2"
          #"--mangoapp"
          #"--expose-wayland" # Seems to break games when HDR enabled
          "--hdr-enabled"
          "--adaptive-sync"
          #"--hdr-debug-force-output"
          #"--hdr-sdr-content-nits 500"
          #"--hdr-itm-enable"
          #"--hdr-itm-target-nits=700"
          #"--hdr-itm-sdr-nits=300"
        ];
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false; # Needed or gamescope fails within Steam; Band-aided with ananicy
      env = {
        #MANGOHUD = "0";
        #MANGOHUD_CONFIG = "read_cfg,no_display,blacklist=test";
        #MANGOHUD_CONFIGFILE="~/.config/MangoHud/MangoHud.conf";
        #VK_LOADER_LAYERS_DISABLE = "VK_LAYER_MANGOHUD_overlay_64_x86_64,VK_LAYER_MANGOHUD_overlay_32_x86";
        #WLR_RENDERER = "vulkan";
        DXVK_HDR = "1";
        ENABLE_GAMESCOPE_WSI = "1";
        ENABLE_HDR_WSI = "0";
        STEAM_MULTIPLE_XWAYLANDS = "1";
      };
      args = [
        "-f"
        "--xwayland-count 2"
        #"--backend sdl" # https://github.com/ValveSoftware/gamescope/issues/1622 and causes stutter (maybe https://github.com/ValveSoftware/gamescope/issues/995)
        "--hdr-enabled"
        "--adaptive-sync"
        #"--force-grab-cursor" # Breaks games with launchers (Elden Ring)
        #"-r 360" # Default that is a multiple of 120 and 180
        #"--mangoapp"
      ];
    };
  };

  hardware = {
    amdgpu.overdrive.enable = true;
  	graphics = {
  	  enable32Bit = true; # Enables support for 32bit libs that steam uses
  	};
  	# TODO: https://github.com/NixOS/nixpkgs/issues/357693
  	#xpadneo.enable = true; 
  	#xone.enable = true;
  	#openrazer.enable = true;
  };

  services = {
    udev.extraRules = ''
      ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="*Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      ACTION=="add|change", KERNEL=="event[0-9]*", ATTRS{name}=="Sunshine*Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';

    cpupower-gui.enable = true;
    lact.enable = true;

 	ananicy = {
 	  enable = true;
 	  package = pkgs.ananicy-cpp;
 	  rulesProvider = pkgs.ananicy-rules-cachyos;
      # Breaks login 50% of the time, possibly since Sway run under sddm?
 	  #extraTypes = [
 	  #  {
 	  #    type = "LowLatency_RT";
 	  #    sched = "rr";
 	  #  }
 	  #];
 	  extraRules = [
 	    # -12: https://github.com/CachyOS/ananicy-rules/blob/master/00-default/DEs-and-WMs/sway.rules
 	    #{
 	    #  name = "sway";
 	    #  nice = -20;
 	    #}
 	    # 
 	    # No longer needed: https://github.com/NixOS/nixpkgs/pull/319634
 	    #{
 	    #  name = ".sway-wrapped";
 	    #  nice = -20;
 	    #}
 	    # -20: https://github.com/CachyOS/ananicy-rules/blob/master/00-default/games/gamescope.rules
 	    #{
 	    #  name = "gamescope";
 	    #  type = "LowLatency_RT";
 	    #}
 	    #{
 	    #  name = "gamescope-wl";
 	    #  type = "LowLatency_RT";
 	    #}
 	    {
 	      name = "sunshine";
 	      type = "LowLatency_RT";
 	    }
 	  ];
 	};
  };

  environment = {
  	systemPackages = with pkgs; [
  	  gsc
  	  steam-run
  	  steamtinkerlaunch
  	  # https://github.com/ValveSoftware/steam-for-linux/issues/11479
  	  # cd to /tmp to somehow avoid stutters with VRR
  	  (if config.programs.steam.gamescopeSession.enable then (pkgs.writeTextDir "share/applications/steam-gamescope.desktop" ''
  	    [Desktop Entry]
  	    Name=Steam (Gamescope)
  	    Comment=Launch Steam via Gamescope (Embedded)
  	    Exec=/usr/bin/env bash -c "cd /tmp && gsc -e -- steam -tenfoot -pipewire-dmabuf -console -cef-force-gpu"
  	    Icon=steam
  	    Type=Application
  	    Categories=Game;
  	  '') else null)
  	  (if config.programs.gamescope.enable then gamescope-wsi else null)
  	  samrewritten
  	  sgdboop
  	  moonlight-qt
  	  unstable.lutris
  	  unstable.xivlauncher
  	  vkbasalt
  	  protontricks
  	  protonplus
	  unstable.ludusavi
	  unstable.ryujinx
	  # citra-mk7 TODO: https://github.com/NixOS/nixpkgs/pull/348927
	  dolphin-emu
	  unstable.cemu
	  (unstable.melonDS.overrideAttrs (finalAttrs: prevAttrs: {
	    qtWrapperArgs = prevAttrs.qtWrapperArgs ++ ["--set QT_QPA_PLATFORM xcb"];
	  }))
      (retroarch.withCores (cores: with cores; [
        mgba
      ]))
  	  #wineWowPackages.stagingFull
  	  wineWowPackages.waylandFull
  	  winetricks
  	  latencyflex-vulkan
  	];

  	variables = {
  	  "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS" = "0";
  	  #"MANGOHUD" = "1";
  	  "MESA_GIT" = lib.concatStringsSep ":" [
  	    "${pkgs.mesa_git}/share/vulkan/icd.d/radeon_icd.x86_64.json"
  	    "${pkgs.mesa32_git}/share/vulkan/icd.d/radeon_icd.i686.json"
  	  ];
  	};
  };

  # Sourced from https://github.com/Jovian-Experiments/Jovian-NixOS/blob/c40d2f31f92571bf341497884174a132829ef0fc/modules/steamos/sysctl.nix#L38
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = lib.mkDefault 0;
    # > This is required due to some games being unable to reuse their TCP ports
    # > if they're killed and restarted quickly - the default timeout is too large.
    #  - https://github.com/Jovian-Experiments/steamos-customizations-jupiter/commit/4c7b67cc5553ef6c15d2540a08a737019fc3cdf1
    "net.ipv4.tcp_fin_timeout" = lib.mkDefault 5;
    # > USE MAX_INT - MAPCOUNT_ELF_CORE_MARGIN.
    # > see comment in include/linux/mm.h in the kernel tree.
    #  - https://github.com/Jovian-Experiments/steamos-customizations-jupiter/commit/e21954bb4743635a9c53016def5158469fa6d7a8
    "vm.max_map_count" = lib.mkForce 2147483642;
  };
}
