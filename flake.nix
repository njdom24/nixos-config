{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here is an working example:
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.
	nixpkgs-legacy.url = "github:nixos/nixpkgs/nixos-25.05";

    # Home manager
    home-manager-stable.url = "github:nix-community/home-manager/release-25.11";
    home-manager-stable.inputs.nixpkgs.follows = "nixpkgs-stable";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs";

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    kwin-effects-forceblur = {
      url = "github:taj-ny/kwin-effects-forceblur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    xwayland-satellite = {
      url = "github:Supreeeme/xwayland-satellite";
      #url = "github:Supreeeme/xwayland-satellite?ref=unscaled-dpi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sway-git = {
      url = "github:swaywm/sway";
      flake = false;
    };
    wlroots-git = {
      url = "git+https://gitlab.freedesktop.org/wlroots/wlroots.git";
      flake = false;
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mesa-git = {
      url = "github:chaotic-cx/mesa-mirror"; # Faster, less-likely to get rate-limited
      #url = "git+https://gitlab.freedesktop.org/mesa/mesa.git";
      flake = false;
    };
    #hyprland.url = "github:UjinT34/Hyprland/fp16?submodules=1";

    #hy3 = {
    #  url = "github:outfoxxed/hy3";
    #  #url = "github:outfoxxed/hy3?ref=hl{version}"; # where {version} is the hyprland release version
    #  # or "github:outfoxxed/hy3" to follow the development branch.
    #  # (you may encounter issues if you dont do the same for hyprland)
    #  inputs.hyprland.follows = "hyprland";
    #};
    # Waiting on:
      # https://github.com/outfoxxed/hy3/issues/162
      # https://github.com/outfoxxed/hy3/issues/223

    # TODO: Add any other flake you might need
    hardware.url = "github:nixos/nixos-hardware";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    self,
    nixpkgs-stable,
    nixpkgs,
    home-manager,
    home-manager-stable,
    plasma-manager,
    xwayland-satellite,
    sway-git,
    wlroots-git,
    hyprland,
    #hy3,
    hardware,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs {
      pkgs = nixpkgs.legacyPackages.${system};
      inputs = inputs;
    });
    
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      damino-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./hosts/damino-desktop
          hardware.nixosModules.common-cpu-amd
        ];
      };

      damino-secondary = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./hosts/damino-desktop/secondary.nix
          hardware.nixosModules.common-cpu-amd
        ];
      };

      damino-framework = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./hosts/damino-framework
          hardware.nixosModules.framework-11th-gen-intel
        ];
      };

      eitherys = nixpkgs-stable.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main nixos configuration file <
          ./hosts/eitherys
          hardware.nixosModules.common-cpu-intel
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "damino@damino-desktop" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {
          inherit inputs outputs;
        };
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/damino/damino-desktop.nix
        ];
      };

      "damino@damino-secondary" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {
          inherit inputs outputs;
        };
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/damino/damino-secondary.nix
        ];
      };

      "damino@damino-framework" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {
          inherit inputs outputs;
        };
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/damino/damino-framework.nix
        ];
      };

      "elpis@eitherys" = home-manager-stable.lib.homeManagerConfiguration {
        pkgs = nixpkgs-stable.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {
          inherit inputs outputs;
        };
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/elpis/eitherys.nix
        ];
      };
    };
  };
}
