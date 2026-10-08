# tests/real/dendrites/gated.nix — home halves under conditions. `fixtureUndeclared`
# is an option Home Manager does not declare, as `stylix` is not until its module
# is enabled: a false condition must never define it.
{ lib, ... }:
lib.mkMerge [
  (lib.mkIf false {
    habit.home.fixtureUndeclared.enable = true;
  })
  (lib.mkIf true {
    habit.home.home.sessionVariables.GATED = "on";
  })
  {
    habit.home = lib.mkIf false {
      fixtureUndeclared.theme = "dark";
    };
  }
]
