{ lib, ... }:
lib.mkIf true (
  lib.mkMerge [
    {
      sys.a = "1";
      habit.home.a = "x";
    }
    { sys.b = "2"; }
  ]
)
