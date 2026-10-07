# The home half itself under a condition, not the module's config.
{ lib, ... }:
{
  habit.home = lib.mkIf false { k = "h"; };
}
