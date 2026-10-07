# tests/real/dendrites/selected.nix — a home half reads the selection of its own
# scope.
{
  habit.home =
    { config, lib, ... }:
    {
      home.sessionVariables.SELECTED = lib.concatStringsSep "," (
        lib.attrNames (lib.filterAttrs (_: s: s.enable) config.habit.selected)
      );
    };
}
