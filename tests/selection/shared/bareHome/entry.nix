# One entry file for both names, with the home half as a bare path: the trap.
{
  imports = [ ../../../../examples/shared/dendrites/runtime.nix ];

  habit.home = ../../../../examples/shared/dendrites/runtime-home.nix;
}
