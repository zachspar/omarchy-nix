{
  description = "Omarchy desktop experience for NixOS — Hyprland, Walker, Ghostty, unified theming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      nixosModules = {
        default = self.nixosModules.omarchy;
        omarchy = import ./modules/nixos;
      };

      homeManagerModules = {
        default = self.homeManagerModules.omarchy;
        omarchy = import ./modules/home-manager;
      };

      overlays.default = final: _prev: {
        omarchy-theme-tools = final.callPackage ./pkgs/omarchy-theme-tools { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          omarchy-theme-tools = pkgs.callPackage ./pkgs/omarchy-theme-tools { };
          default = omarchy-theme-tools;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      templates.minimal = {
        path = ./examples/minimal;
        description = "Minimal NixOS host importing programs.omarchy";
      };
    };
}
