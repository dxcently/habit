{
  description = "habit against real NixOS, Home Manager and nix-darwin, evaluated from Linux";

  # Separate from the root flake so the root lock holds one input and a consumer's
  # lock gains none. Home Manager and nix-darwin are pinned to revisions that
  # evaluate against the nixpkgs habit's own checks use.
  inputs = {
    habit.url = "path:..";
    nixpkgs.follows = "habit/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager/fae6e9e42c3b762ab47635cddcfaf6f52374a61b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      habit,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      cases = import ./real { inherit habit nixpkgs home-manager nix-darwin; };

      check =
        name:
        { got, want }:
        if got == want then
          pkgs.runCommand "habit-${name}" { } ''
            printf '%s\n' ${lib.escapeShellArg (builtins.unsafeDiscardStringContext (builtins.toJSON got))} > $out
          ''
        else
          throw "habit check ${name}: wanted ${builtins.toJSON want}, got ${builtins.toJSON got}";
    in
    {
      checks.x86_64-linux = lib.mapAttrs check cases;
    };
}
