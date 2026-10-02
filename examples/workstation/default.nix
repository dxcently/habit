# examples/workstation/default.nix — a group, a provider choice, a home user.
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
  hostModules = [ ./hosts/desk.nix ];
  nucleus = ./nucleus.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
