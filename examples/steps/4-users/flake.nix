# examples/steps/4-users/flake.nix
{
  description = "habit, step 4: users, one who opts out, one who picks a shell";

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
      build =
        host:
        (composition.mkNixosHost {
          inherit nixpkgs;
          hostName = host;
          registry = import ./modules/default.nix;
          host = ./hosts + "/${host}/default.nix";
          homeManagerModule = home-manager.nixosModules.home-manager;
        }).system;
    in
    {
      nixosConfigurations = {
        desk = build "desk";
        laptop = build "laptop";
      };
    };
}
