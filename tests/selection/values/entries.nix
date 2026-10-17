# Catalogue entries that are module values, not paths. The value cases merge
# them into the fixture registry. An entry that throws is one the cases leave
# unselected, and a selecting case shows that it would have thrown.
let
  dup = {
    fixture.marks = [ "dup" ];
  };
in
{
  attrsValue = {
    fixture.marks = [ "attrs" ];
  };

  functionValue =
    { lib, ... }:
    {
      fixture.marks = lib.optional true "function";
    };

  attrsWithFile = {
    _file = "values/attrsWithFile.nix";
    fixture.marks = [ "file" ];
  };

  homeValue = {
    habit.home.fixture.marks = [ "home" ];
  };

  throwingFunction = _: throw "applied";

  throwingConfig = {
    config = throw "config forced";
  };

  badValue = {
    habit.homee = { };
  };

  badFile = {
    _file = "values/badFile.nix";
    habit.homee = { };
  };

  notAModule = 3;

  # A function module that takes a module argument: the host's own name.
  argValue =
    { host, ... }:
    {
      fixture.marks = [ host ];
    };

  # One value under two names: each name is its own entry, so both apply.
  dupA = dup;
  dupB = dup;

  # A path-like attrset (`outPath`, as a derivation or a flake input is): a path.
  outPathEntry = { outPath = ./../dendrites/homeonly/default.nix; };

  importsHabitKey = {
    imports = [ { habit.dendrites.systemonly.enable = true; } ];
  };
}
