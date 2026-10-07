{ lib, ... }:
{
  freeformType = lib.types.lazyAttrsOf lib.types.anything;
  habit.home.k = "h";
}
