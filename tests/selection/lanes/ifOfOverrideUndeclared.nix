# A false condition outside a priority, over an undeclared option.
{ lib, ... }:
lib.mkIf false (lib.mkOverride 10 { habit.home.undeclared = "h"; })
