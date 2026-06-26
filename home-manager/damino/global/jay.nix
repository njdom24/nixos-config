{ inputs, lib, config, pkgs, ... }: {
  imports = [
  ];
  xdg.portal = {
    configPackages = [ pkgs.jay ];
    config.jay = {
      default = [
        "jay"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "jay" ];
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "jay" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  home = {
    packages = with pkgs; [
      (pkgs.writeShellScriptBin "jay-toggle-hdr" ''
        #!/usr/bin/env bash
        # TODO
      '')
    ];
  };
}
