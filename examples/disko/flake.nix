{
  description = "NixOS host using programs.omarchy.storage.disko — WIPES THE TARGET DISK";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omarchy-nix = {
      url = "github:zachspar/omarchy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      omarchy-nix,
      ...
    }:
    {
      nixosConfigurations.omarchy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          omarchy-nix.nixosModules.default
          omarchy-nix.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./configuration.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alice = {
              imports = [
                omarchy-nix.homeManagerModules.default
                ./home.nix
              ];
            };
          }
        ];
      };
    };
}
