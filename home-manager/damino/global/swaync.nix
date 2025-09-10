{ inputs, lib, config, pkgs, ... }: {
  imports = [
  ];

  services = {
    swaync = {
      enable = true;
      settings = {
        timeout = 4;
        notification-window-preferred-output = "DP-2";
        notification-window-width = 350;
      };
      # Adapted from https://github.com/catppuccin/swaync
      style = ''
        :root {
          --base00: #${config.colorScheme.palette.base00};
          --base01: #${config.colorScheme.palette.base01};
          --base02: #${config.colorScheme.palette.base02};
          --base03: #${config.colorScheme.palette.base03};
          --base04: #${config.colorScheme.palette.base04};
          --base05: #${config.colorScheme.palette.base05};
          --base06: #${config.colorScheme.palette.base06};
          --base07: #${config.colorScheme.palette.base07};
          --base08: #${config.colorScheme.palette.base08};
          --base09: #${config.colorScheme.palette.base09};
          --base0A: #${config.colorScheme.palette.base0A};
          --base0B: #${config.colorScheme.palette.base0B};
          --base0C: #${config.colorScheme.palette.base0C};
          --base0D: #${config.colorScheme.palette.base0D};
          --base0E: #${config.colorScheme.palette.base0E};
          --base0F: #${config.colorScheme.palette.base0F};
        }
        
        * {
          all: unset;
          font-size: 14px;
          #font-family: "Ubuntu Nerd Font";
          transition: 200ms;
        }
        
        trough highlight {
          background: var(--base05);
        }
        
        scale {
          margin: 0 7px;
        }
        
        scale trough {
          margin: 0rem 1rem;
          min-height: 8px;
          min-width: 70px;
          border-radius: 12.6px;
        }
        
        trough slider {
          margin: -10px;
          border-radius: 12.6px;
          box-shadow: 0 0 2px rgba(0, 0, 0, 0.8);
          transition: all 0.2s ease;
          background-color: var(--base0D);
        }
        
        trough slider:hover {
          box-shadow: 0 0 2px rgba(0, 0, 0, 0.8), 0 0 8px var(--base0D);
        }
        
        trough {
          background-color: var(--base01);
        }
        
        /* notifications */
        .notification-background {
          box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px var(--base02); /* Border color */
          border-radius: 6.6px;
          margin: 18px;
          background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base00}, 0.8); /* base00 with 80% opacity */
          color: var(--base05);
          padding: 0;
        }
        
        .notification-background .notification {
          padding: 7px;
          border-radius: 12.6px;
        }

        .notification image {
          min-width: 64px;
          min-height: 64px;
          max-width: 96px;
          max-height: 96px;
        }
        
        .notification-background .notification.critical {
          box-shadow: inset 0 0 7px 0 var(--base08);
        }
        
        .notification .notification-content {
          margin: 7px;
        }
        
        .notification .notification-content overlay {
          margin: 4px;
        }
        
        .notification-content .summary {
          color: var(--base05);
        }
        
        .notification-content .time {
          color: var(--base04);
        }
        
        .notification-content .body {
          color: var(--base06);
        }
        
        .notification > *:last-child > * {
          min-height: 3.4em;
        }
        
        .notification-background .close-button {
          margin: 7px;
          padding: 2px;
          border-radius: 6.3px;
          color: var(--base00);
          background-color: var(--base08);
        }
        
        .notification-background .close-button:hover {
          background-color: var(--base09);
        }
        
        .notification-background .close-button:active {
          background-color: var(--base0E);
        }
        
        .notification .notification-action {
          border-radius: 7px;
          color: var(--base05);
          box-shadow: inset 0 0 0 1px var(--base02);
          margin: 4px;
          padding: 8px;
          font-size: 0.2rem;
          background-color: var(--base01);
        }
        
        .notification .notification-action:hover {
          background-color: var(--base02);
        }
        
        .notification .notification-action:active {
          background-color: var(--base03);
        }
        
        .notification.critical progress {
          background-color: var(--base08);
        }
        
        .notification.low progress,
        .notification.normal progress {
          background-color: var(--base0D);
        }
        
        .notification progress,
        .notification trough,
        .notification progressbar {
          border-radius: 12.6px;
          padding: 3px 0;
        }
        
        /* control center */
        .control-center {
          box-shadow: 0 0 8px 0 rgba(0, 0, 0, 0.8), inset 0 0 0 1px var(--base01);
          border-radius: 12.6px;
          background-color: rgba(${inputs.nix-colors.lib.conversions.hexToRGBString ", " config.colorScheme.palette.base00}, 0.9); /* base00 with 90% opacity */
          color: var(--base05);
          padding: 14px;
        }
        
        .control-center .notification-background {
          border-radius: 7px;
          box-shadow: inset 0 0 0 1px var(--base02);
          margin: 4px 10px;
        }
        
        .control-center .notification-background .notification {
          border-radius: 7px;
        }
        
        .control-center .notification-background .notification.low {
          opacity: 0.8;
        }
        
        .control-center .widget-title > label {
          color: var(--base05);
          font-size: 1.3em;
        }
        
        .control-center .widget-title button {
          border-radius: 7px;
          color: var(--base05);
          background-color: var(--base01);
          box-shadow: inset 0 0 0 1px var(--base02);
          padding: 8px;
        }
        
        .control-center .widget-title button:hover {
          background-color: var(--base02);
        }
        
        .control-center .widget-title button:active {
          background-color: var(--base03);
        }
        
        .control-center .notification-group {
          margin-top: 10px;
        }
        
        scrollbar slider {
          margin: -3px;
          opacity: 0.8;
        }
        
        scrollbar trough {
          margin: 2px 0;
        }
        
        /* dnd */
        .widget-dnd {
          margin-top: 5px;
          border-radius: 8px;
          font-size: 1.1rem;
        }
        
        .widget-dnd > switch {
          font-size: initial;
          border-radius: 8px;
          background: var(--base01);
          box-shadow: none;
        }
        
        .widget-dnd > switch:checked {
          background: var(--base0D);
        }
        
        .widget-dnd > switch slider {
          background: var(--base02);
          border-radius: 8px;
        }
        
        /* mpris */
        .widget-mpris-player {
          background: var(--base01);
          border-radius: 12.6px;
          color: var(--base05);
        }
        
        .mpris-overlay {
          background-color: var(--base01);
          opacity: 0.9;
          padding: 15px 10px;
        }
        
        .widget-mpris-album-art {
          -gtk-icon-size: 100px;
          border-radius: 12.6px;
          margin: 0 10px;
        }
        
        .widget-mpris-title {
          font-size: 1.2rem;
          color: var(--base05);
        }
        
        .widget-mpris-subtitle {
          font-size: 1rem;
          color: var(--base06);
        }
        
        .widget-mpris button {
          border-radius: 12.6px;
          color: var(--base05);
          margin: 0 5px;
          padding: 2px;
        }
        
        .widget-mpris button image {
          -gtk-icon-size: 1.8rem;
        }
        
        .widget-mpris button:hover {
          background-color: var(--base01);
        }
        
        .widget-mpris button:active {
          background-color: var(--base02);
        }
        
        .widget-mpris button:disabled {
          opacity: 0.5;
        }
        
        .widget-menubar > box > .menu-button-bar > button > label {
          font-size: 3rem;
          padding: 0.5rem 2rem;
        }
        
        .widget-menubar > box > .menu-button-bar > :last-child {
          color: var(--base08);
        }
        
        .power-buttons button:hover,
        .powermode-buttons button:hover,
        .screenshot-buttons button:hover {
          background: var(--base01);
        }
        
        .control-center .widget-label > label {
          color: var(--base05);
          font-size: 2rem;
        }
        
        .widget-buttons-grid {
          padding-top: 1rem;
        }
        
        .widget-buttons-grid > flowbox > flowboxchild > button label {
          font-size: 2.5rem;
        }
        
        .widget-volume {
          padding: 1rem 0;
        }
        
        .widget-volume label {
          color: var(--base0C);
          padding: 0 1rem;
        }
        
        .widget-volume trough highlight {
          background: var(--base0C);
        }
        
        .widget-backlight trough highlight {
          background: var(--base0A);
        }
        
        .widget-backlight label {
          font-size: 1.5rem;
          color: var(--base0A);
        }
        
        .widget-backlight .KB {
          padding-bottom: 1rem;
        }
        
        .image {
          padding-right: 0.5rem;
        }
        
      '';
    };
  };
  systemd.user.services.swaync = lib.mkForce { };

  home = {
  };
}
