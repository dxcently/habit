# `imports` guarded by platform configuration are dropped, not evaluated.
{ config, lib, ... }:
{
  imports = lib.optionals config.foo [ ./importThrows.nix ];
  habit.dendrites.systemonly.enable = true;
}
