{ config, pkgs, lib, inputs, ... }:

let
  antiLagSo = ./libVkLayer_MESA_anti_lag.so;  # path to your .so relative to your flake/config

  low-latency-layer = pkgs.stdenv.mkDerivation {
    pname = "low-latency-layer";
    version = "0.02";

    src = inputs.low-latency-layer-git;

    nativeBuildInputs = with pkgs; [
      cmake
    ];

    buildInputs = with pkgs; [
      vulkan-headers
      vulkan-utility-libraries
      vulkan-loader
    ];

    # Install under ~/.local instead of system-wide by using the home prefix.
    # CMake's GNUInstallDirs will derive lib/ and share/ from this.
    cmakeFlags = [
      "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    ];

    meta = {
      description = "Vulkan layer for hardware-agnostic input latency reduction (Reflex / Anti-Lag)";
      homepage = "https://github.com/Korthos-Software/low_latency_layer";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
in
{
  # Deploy the JSON manifest
  home.file.".local/share/vulkan/implicit_layer.d/VkLayer_MESA_anti_lag.json".text = builtins.toJSON {
    file_format_version = "1.2.1";
    layer = {
      name = "VK_LAYER_MESA_anti_lag";
      type = "GLOBAL";
      library_path = "${config.home.homeDirectory}/.local/lib/libVkLayer_MESA_anti_lag.so";
      api_version = "1.4.303";
      implementation_version = "1";
      description = "Open-source implementation of the VK_AMD_anti_lag extension.";
      functions = {
        vkNegotiateLoaderLayerInterfaceVersion = "anti_lag_NegotiateLoaderLayerInterfaceVersion";
      };
      device_extensions = [{
        name = "VK_AMD_anti_lag";
        spec_version = "1";
        entrypoints = [ "vkAntiLagUpdateAMD" ];
      }];
      disable_environment = { DISABLE_LAYER_MESA_ANTI_LAG = "1"; };
      enable_environment = { ENABLE_LAYER_MESA_ANTI_LAG = "1"; };
    };
  };

  # Deploy the .so
  home = {
    packages = [ low-latency-layer ];
    sessionVariables = {
       VK_ADD_IMPLICIT_LAYER_PATH = "${low-latency-layer}/share/vulkan/implicit_layer.d";
       LOW_LATENCY_LAYER_REFLEX = "1";
       PROTON_FORCE_NVAPI = "1"; # Needed for Reflex 2 on non-NVIDIA hardware
       # LOW_LATENCY_SPOOF_NVIDIA = "1";
       # DISABLE_LOW_LATENCY = "0";
    };
    
    file.".local/lib/libVkLayer_MESA_anti_lag.so" = {
      source = antiLagSo;
      executable = true;
    };
  };
}
