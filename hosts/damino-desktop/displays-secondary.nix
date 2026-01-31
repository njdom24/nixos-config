# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, lib, ... }: {
  hardware = {
    # https://github.com/NixOS/nixpkgs/pull/279789#issuecomment-2148560802
    display = {
      outputs."DP-1".edid = "edid_aoc_Q27G40XMN_72vrr.bin"; # Increase VRR range to 70 to work around flicker
      outputs."DP-1".mode = "e";
      outputs."HDMI-A-1".edid = "edid_55r635.bin"; # Add VRR range (48-120), EDID MaxFALL 686 MaxCLL 1114 MinCLL 0.1
      outputs."HDMI-A-1".mode = "e";
      outputs."DP-3".edid = "edid_q800t_xiaomi_lumi.bin";
      outputs."DP-3".mode = "e";
      edid.packages = [
        (pkgs.runCommand "custom-edid" {} ''
          mkdir -p $out/lib/firmware/edid
          cp ${./edid_aoc_Q27G40XMN_72vrr.bin} $out/lib/firmware/edid/edid_aoc_Q27G40XMN_72vrr.bin
          cp ${./edid_q800t_xiaomi_lumi.bin} $out/lib/firmware/edid/edid_q800t_xiaomi_lumi.bin
          cp ${./edid_55r635.bin} $out/lib/firmware/edid/edid_55r635.bin
        '')
      ];
    };
  };

  environment.sessionVariables = {
  };
}
