{ inputs, lib, config, pkgs, ... }: {
  imports = [
  ];
  xdg.portal = {
    configPackages = [ pkgs.mango ];
    config.mango = {
      default = [
        "wlr"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "wlr" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  home =
    let screenshot = pkgs.writeShellScript "screenshot" ''
      mode="$1"
      SCREENSHOT_DIR="$XDG_RUNTIME_DIR/screenshots"
      mkdir -p "$SCREENSHOT_DIR"
      timestamp=$(date +%s)
      tmpfile="$SCREENSHOT_DIR/$timestamp.png"

      cleanup() {
        rm -f "$tmpfile"
      }
      trap cleanup EXIT

      # Clear out old screenshot
      rm -f "$SCREENSHOT_DIR/"*
      ${pkgs.wl-clipboard-rs}/bin/wl-copy ""

      case "$mode" in
        focused)
          monitor=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r ".[] | select(.focused==true).name")
          ${pkgs.grim}/bin/grim -o "$monitor" "$tmpfile"
          ;;
        select|selector)
          geom=$(${pkgs.slurp}/bin/slurp)
          ${pkgs.grim}/bin/grim -g "$geom" "$tmpfile"
          ;;
        *)
          echo "Usage: $0 {focused|select}" >&2
          exit 1
          ;;
      esac

      if [[ -s "$tmpfile" ]]; then
        # Compression can take a while. Put current image in clipboard for immediate pasting
        ${pkgs.wl-clipboard-rs}/bin/wl-copy --type text/uri-list <<< "file://$tmpfile"
        ${pkgs.libnotify}/bin/notify-send -a "Screenshot" -i "$tmpfile" "Screenshot taken"

        # Compress to WebP for pasting in chat apps
        newfile="$SCREENSHOT_DIR/$timestamp.webp"
        ${pkgs.imagemagick}/bin/magick "$tmpfile" \
          -define webp:lossless=true \
          "$newfile"

        ${pkgs.wl-clipboard-rs}/bin/wl-copy --type text/uri-list <<< "file://$newfile"
        #${pkgs.libnotify}/bin/notify-send -a "Screenshot" -i "$newfile" "Screenshot converted"
      fi
    ''; in {
    packages = with pkgs; [
      wlr-randr
      imagemagick # Temp, remove
    ];

    #file.".config/mango/config.conf" =
    #  let satellite-loop = pkgs.writeShellScript "satellite-loop" ''
    #  while true; do
    #    (sleep 5 && xrandr --output DP-1 --primary) &
    #    ${pkgs.xwayland-satellite}/bin/xwayland-satellite
    #    sleep 1
    #    status=$?
    #    echo "xwayland-satellite exited with status $status, restarting in 1 second..." >&2
    #    sleep 1
    #  done
    #''; in {
    #  text = ''
    #  '';
    #};
  };
}
