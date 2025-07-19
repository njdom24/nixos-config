# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }: {
  hardware = {
    # https://github.com/NixOS/nixpkgs/pull/279789#issuecomment-2148560802
    display = {
      outputs."DP-1".edid = "edid_aoc_Q27G40XMN_72vrr.bin"; # Increase VRR range to 70 to work around flicker
      outputs."DP-1".mode = "e";
      outputs."HDMI-A-1".edid = "edid_qm851g.bin"; # Fix 1440p144hz, VRR to 70+ to work around judder (LFC instead), prevent blanking (48 -> 40 FRL), HDR Metadata MaxFALL 800 MaxCLL 3000 MinCLL 0.1
      outputs."HDMI-A-1".mode = "e";
      #outputs."DP-3".edid = "edid_55r635.bin"; # Add VRR range (48-120), EDID MaxFALL 686 MaxCLL 1114 MinCLL 0.1
      outputs."DP-3".edid = "edid_g8_xiaomi_lumi.bin"; # For "headless" streaming through unused DP port on GPU. 2024 Odyssey G8 OLED (4k240) w/ Xiaomi G Pro 27i's luminance metadata
      outputs."DP-3".mode = "e";
      
      edid.packages = [
        (pkgs.runCommand "custom-edid" {} ''
          mkdir -p $out/lib/firmware/edid
          cp ${./edid_aoc_Q27G40XMN_72vrr.bin} $out/lib/firmware/edid/edid_aoc_Q27G40XMN_72vrr.bin
          cp ${./edid_qm851g.bin} $out/lib/firmware/edid/edid_qm851g.bin
          cp ${./edid_55r635.bin} $out/lib/firmware/edid/edid_55r635.bin
          cp ${./edid_g8_xiaomi_lumi.bin} $out/lib/firmware/edid/edid_g8_xiaomi_lumi.bin
        '')
      ];
    };
  };

  environment.sessionVariables = {
  };
}
