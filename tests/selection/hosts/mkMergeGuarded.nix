# A condition over platform configuration that guards no `habit` key is never
# forced.
{ config, lib, ... }:
{
  config = lib.mkMerge [
    { habit.dendrites.systemonly.enable = true; }
    (lib.mkIf config.foo { services.a.enable = true; })
  ];
}
