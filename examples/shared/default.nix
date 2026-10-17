# examples/shared/default.nix — two entries share one piece with two halves.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  composition = habit.lib.composition { inherit (nixpkgs) lib; };
in
composition.mkNixosHost {
  inherit nixpkgs;
  hostName = "desk";
  registry = import ./registry.nix;
  host = ./hosts/desk.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
