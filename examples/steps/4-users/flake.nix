# examples/steps/4-users/flake.nix
{
  description = "habit, step 4: users, and one of them opts out";

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
