{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ./wlogout.nix
    ./waybar.nix
    ./rofi.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
  };

  home = {
    packages = with pkgs; [
      
    ];
  };
}
