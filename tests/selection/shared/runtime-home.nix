{ lib, ... }:
{
  options.example.runtime.home = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config.example.runtime.home = [ "runtime" ];
}
