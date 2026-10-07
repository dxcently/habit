# tests/real/dendrites/forced.nix — a home half under `mkOverride`: it reaches
# the user beside the plain one, and wins the option the two both set.
{ lib, ... }:
{
  habit.home = lib.mkOverride 10 {
    home.preferXdgDirectories = true;
    home.language.base = "forced";
  };
}
