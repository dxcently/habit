# A false condition over a merge whose home half sets an undeclared option.
{ lib, ... }:
lib.mkIf false (
  lib.mkMerge [
    {
      sys.a = "1";
      habit.home.undeclared = "x";
    }
    { sys.b = "2"; }
  ]
)
