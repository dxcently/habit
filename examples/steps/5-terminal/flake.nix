# examples/steps/5-terminal/flake.nix
{
  description = "habit, step 5: a second capability, and a group that selects both";

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
      composition = habit.lib.composition { inherit (nixpkgs) lib; };
    in
    {
      nixosConfigurations.desk =
        (composition.mkNixosHost {
          inherit nixpkgs;
          hostName = "desk";
          registry = import ./modules/default.nix;
          host = ./hosts/desk/default.nix;
          homeManagerModule = home-manager.nixosModules.home-manager;
        }).system;
    };
}
