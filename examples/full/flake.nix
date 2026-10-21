# examples/full/flake.nix
{
  description = "A desk, a server and a standalone home, one registry and two sources: the habit template";

  inputs = {
    habit.url = "github:dxcently/habit";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    habit.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      habit,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      composition = habit.lib.composition { inherit lib; };
      catalogues = habit.lib.catalogues { inherit lib; };
      registry = catalogues.mergeRegistries [
        (import ./modules/default.nix // { name = "core"; })
        (import ./modules/personal/default.nix // { name = "personal"; })
      ];
      nixosHost =
        name:
        (composition.mkNixosHost {
          inherit nixpkgs registry;
          hostName = name;
          host = ./hosts + "/${name}/default.nix";
          homeManagerModule = home-manager.nixosModules.home-manager;
        }).system;
    in
    {
      nixosConfigurations = {
        desk = nixosHost "desk";
        server = nixosHost "server";
      };

      homeConfigurations.alice =
        (composition.mkHome {
          inherit home-manager registry;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          hostName = "alice";
          host = ./hosts/alice/default.nix;
        }).home;
    };
}
