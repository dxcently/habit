{ lib, ... }:
{
  options.dendrites = lib.mkOption {
    type = lib.types.str;
    default = "";
  };
}
