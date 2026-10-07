{ lib, config, ... }:
{
  options.fn.shout = lib.mkOption {
    type = lib.types.str;
    default = "ok";
  };
  config.out.fn = lib.toUpper config.fn.shout;
}
