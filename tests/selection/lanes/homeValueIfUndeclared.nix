# The home half itself under a false condition, over an undeclared option.
{ lib, ... }:
{
  habit.home = lib.mkIf false { undeclared = "h"; };
}
