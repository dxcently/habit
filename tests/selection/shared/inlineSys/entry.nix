# One entry file for both names, with the system half imported inline: the trap.
{
  imports = [ (import ../../../../examples/shared/dendrites/runtime.nix) ];

  habit.home.imports = [ ../../../../examples/shared/dendrites/runtime-home.nix ];
}
