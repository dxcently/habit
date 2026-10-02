# examples/minimal/default.nix — one capability, one host.
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
  hostName = "box";
  registry = import ./registry.nix;
  hostModules = [ ./hosts/box.nix ];
  nucleus = ./nucleus.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
