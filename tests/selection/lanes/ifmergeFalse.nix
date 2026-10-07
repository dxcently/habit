# A condition over a merge covers every part of it.
{ lib, ... }:
lib.mkIf false (
  lib.mkMerge [
    { habit.home.a = "x"; }
    { habit.home.b = "y"; }
  ]
)
