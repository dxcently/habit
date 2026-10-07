# A condition cannot cover a home half's options, so this is refused.
{ lib, ... }:
lib.mkIf true {
  habit.home.options.x = lib.mkOption {
    type = lib.types.str;
    default = "x";
  };
}
