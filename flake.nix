{
  description = "habit — host composition: select capabilities from a registry before NixOS evaluates";

  # nixpkgs is used ONLY by `checks`. The library takes `lib` from its consumer
  # and reads no input, so a consumer sets `inputs.habit.inputs.nixpkgs.follows`
  # to its own and this pin never reaches its evaluation.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/e554fab72f81915600f3f449b786fd9af40439a5";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      # Each entry is its file's own function of `{ lib }`, UNAPPLIED: a consumer
      # applies it with the `lib` its own host evaluation uses.
      lib = {
        composition = import ./lib/composition.nix;
        catalogues = import ./lib/catalogues.nix;
      };

      checks.x86_64-linux.selection =
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

      # The book in docs/, published to GitHub Pages from this output. It is
      # built only after every quoted example file is checked against the file.
      checks.x86_64-linux.docs =
        pkgs.runCommand "habit-docs"
          {
            nativeBuildInputs = [ pkgs.mdbook ];
            src = self;
          }
          ''
            bash $src/tests/docs/quotes.sh
            mdbook build $src/docs -d $out
          '';
    };
}
