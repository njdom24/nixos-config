# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }: {
  hardware = {
    # https://github.com/NixOS/nixpkgs/pull/279789#issuecomment-2148560802
    display = {
      outputs."DP-3".edid = "edid_q800t_xiaomi_lumi.bin"; # For "headless" streaming through unused DP port on GPU. 2024 Odyssey G8 OLED (4k240) w/ Xiaomi G Pro 27i's luminance metadata
      outputs."DP-3".mode = "e";
      outputs."HDMI-A-1".mode = "e";
      outputs."HDMI-A-1".edid = "edid_qm851g_hdr_ugreen_32frl.bin"; # Add VRR range and HDR metadata for Chrontel CH7218 adapter
      
      edid.packages = [
        (pkgs.runCommand "custom-edid" {} ''
          mkdir -p $out/lib/firmware/edid
          cp ${./edid_q800t_xiaomi_lumi.bin} $out/lib/firmware/edid/edid_q800t_xiaomi_lumi.bin
          cp ${./edid_qm851g_hdr_ugreen_32frl.bin} $out/lib/firmware/edid/edid_qm851g_hdr_ugreen_32frl.bin
        '')
      ];
    };
  };

  environment.sessionVariables = {
  };
}
