# One entry file for both names, with the home half as a bare path: the trap.
{
  imports = [ ../runtime.nix ];

  habit.home = ../runtime-home.nix;
}
