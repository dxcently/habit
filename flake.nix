{
  description = "habit — host composition: select capabilities from a registry before NixOS evaluates";

  # nixpkgs is used ONLY by `checks`. The library takes `lib` from its consumer
  # and reads no input, so a consumer sets `inputs.habit.inputs.nixpkgs.follows`
  # to its own and this pin never reaches its evaluation.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/e554fab72f81915600f3f449b786fd9af40439a5";

  outputs =
    { self, nixpkgs }:
    {
      # Each entry is its file's own function of `{ lib }`, UNAPPLIED: a consumer
      # applies it with the `lib` its own host evaluation uses.
      lib = {
        composition = import ./lib/composition.nix;
        catalogues = import ./lib/catalogues.nix;
      };

      checks.x86_64-linux.selection =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.runCommand "habit-selection"
          {
            nativeBuildInputs = [
              pkgs.nix
              pkgs.jq
              pkgs.bash
            ];
            src = self;
            HABIT_LIB = "import ${nixpkgs}/lib";
          }
          ''
            export HOME=$TMPDIR NIX_CONFIG='experimental-features = nix-command'
            cp -r $src/. source
            chmod -R u+w source
            bash source/tests/selection/run.sh > $out || { cat $out; exit 1; }
            cat $out
          '';
    };
}
