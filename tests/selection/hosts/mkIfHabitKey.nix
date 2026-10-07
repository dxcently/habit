{ config, lib, ... }:
{
  habit.dendrites.systemonly.enable = lib.mkIf config.foo true;
}
