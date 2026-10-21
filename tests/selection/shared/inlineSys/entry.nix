# One entry file for both names, with the system half imported inline: the trap.
{
  imports = [ (import ../runtime.nix) ];

  habit.home.imports = [ ../runtime-home.nix ];
}
