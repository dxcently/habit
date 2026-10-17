# examples/shared/dendrites/bar.nix
{
  imports = [ ./runtime.nix ];

  habit.home.imports = [ ./runtime-home.nix ];
}
