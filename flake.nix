{
  description = "Nebula OS";

  inputs = {
    zen-browser = { # Firefox-форк, core/packages.nix
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = { # моди/теми для Spotify-клієнта, crew/media.nix
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Гілка cachix (не main) — саме ті ревізії, під які реально збираються
    # закешовані білди на noctalia.cachix.org. НЕ додавати
    # inputs.nixpkgs.follows тут: follows змінює derivation hash і зносить
    # усі кеш-хіти, збірка піде локально з нуля (alpha Quickshell-стек, довго).
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {

    packages.x86_64-linux.halley = (import nixpkgs { system = "x86_64-linux"; }).callPackage ./pkgs/halley/default.nix {};

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

    nixosConfigurations.earth = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs self; };
      modules = [
        ./hosts/earth/default.nix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.ryudzyn = import ./crew/default.nix;
        }
      ];
    };
  };
}