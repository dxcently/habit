{ lib, ... }:
{
  options.opt.level = lib.mkOption {
    type = lib.types.int;
    default = 3;
  };
  config.out.level = "set";
}
