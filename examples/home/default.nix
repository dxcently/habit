# examples/home/default.nix — a standalone Home Manager configuration.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  composition = habit.lib.composition { inherit (nixpkgs) lib; };
in
composition.mkHome {
  inherit home-manager;
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  hostName = "alice";
  registry = import ./registry.nix;
  host = ./hosts/alice.nix;
}
