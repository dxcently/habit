# A home half that is a function, under a condition on the module's own option.
{ config, lib, ... }:
{
  options.fn.on = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf config.fn.on {
    habit.home =
      { lib, ... }:
      {
        k = lib.toUpper "h";
      };
  };
}
