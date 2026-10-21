# examples/steps/1-file/flake.nix
{
  description = "habit, step 1: one capability, one file";

  inputs = {
    habit.url = "github:dxcently/habit";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    habit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { habit, nixpkgs, ... }:
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
        }).system;
    };
}
