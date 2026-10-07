# A home half with a priority of its own.
{ lib, ... }:
{
  habit.home = lib.mkOverride 10 { a = "1"; };
}
