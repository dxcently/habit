{ config, lib, ... }:
{
  config = lib.mkIf config.foo {
    habit.dendrites.systemonly.enable = true;
  };
}
