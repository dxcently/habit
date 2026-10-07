# The caller's own `lib` is the host's `lib`, as it is in the module system.
{ lib, ... }:
{
  habit.users.${lib.marker}.definition = ../users/alice.nix;
}
