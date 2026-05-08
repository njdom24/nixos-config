{ config, pkgs, lib, ... }:

let
  antiLagSo = ./libVkLayer_MESA_anti_lag.so;  # path to your .so relative to your flake/config
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
  home.file.".local/lib/libVkLayer_MESA_anti_lag.so" = {
    source = antiLagSo;
    executable = true;
  };
}
