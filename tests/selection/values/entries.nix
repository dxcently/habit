# Catalogue entries that are module values, not paths. The value cases merge
# them into the fixture registry. An entry that throws is one the cases leave
# unselected, and a selecting case shows that it would have thrown.
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

  providerSet = {
    providers = {
      dunst = ../dendrites/notifications/dunst.nix;
    };
  };

  notAModule = 3;
}
