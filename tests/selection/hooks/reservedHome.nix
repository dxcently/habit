{ lib, ... }:
{
  options.home = lib.mkOption {
    type = lib.types.str;
    default = "";
  };
}
