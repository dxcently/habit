# examples/shared/dendrites/dock.nix
{
  imports = [ ./runtime.nix ];

  habit.home.imports = [ ./runtime-home.nix ];
}
