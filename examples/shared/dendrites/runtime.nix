# examples/shared/dendrites/runtime.nix
{ lib, ... }:
{
  options.example.runtime.system = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config.example.runtime.system = [ "runtime" ];
}
