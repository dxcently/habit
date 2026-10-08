# A condition around a home half's options: a user's platform discharges it
# whole, and a home that is itself the evaluation refuses it.
{ lib, ... }:
lib.mkIf true {
  habit.home.options.x = lib.mkOption {
    type = lib.types.str;
    default = "x";
  };
}
