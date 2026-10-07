# A condition outside a priority, the order nixpkgs itself requires.
{ lib, ... }:
lib.mkIf true (lib.mkOverride 10 { habit.home.k = "h"; })
