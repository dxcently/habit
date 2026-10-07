# A lane record: a set of named lanes, none of them options and none of them
# `habit.home`. A module's top-level keys are its configuration, so this is
# configuration for options named `body`, `nixos` and `homeManager`.
{
  body = { };
  nixos = {
    fixture.marks = [ "laneRecord" ];
  };
  homeManager = { };
}
