# examples/merged/default.nix — two registries, one host.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  inherit (nixpkgs) lib;
  composition = habit.lib.composition { inherit lib; };
  catalogues = habit.lib.catalogues { inherit lib; };
in
composition.mkNixosHost {
  inherit nixpkgs;
  hostName = "box";
  registry = catalogues.mergeRegistries [
    (import ./shared/registry.nix // { name = "shared"; })
    (import ./personal/registry.nix // { name = "personal"; })
  ];
  host = ./hosts/box.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
