{
  description = "Nebula OS";

  inputs = {
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    
    # Визначаємо пакет Halley тут
    packages.x86_64-linux.halley = (import nixpkgs { system = "x86_64-linux"; }).callPackage ./pkgs/halley/default.nix {};

    nixosConfigurations.earth = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # Передаємо self, щоб модуль core/packages.nix бачив пакет halley
      specialArgs = { inherit inputs self; }; 
      modules = [
        ./hosts/earth/default.nix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.ryudzyn = import ./crew/default.nix;
        }
      ];
    };
  };
}