# tests/real/default.nix — every case, by name. A case is `{ got; want; }`:
# `tests/flake.nix` turns each into a check that passes when they are equal.
inputs:
let
  inherit (inputs.nixpkgs) lib;
  shared = inputs // {
    enabled = selected: lib.attrNames (lib.filterAttrs (_: s: s.enable) selected);
  };
in
import ./nixos.nix shared // import ./home.nix shared // import ./darwin.nix shared
