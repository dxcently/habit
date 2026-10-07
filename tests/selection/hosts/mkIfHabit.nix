{ config, lib, ... }:
{
  habit = lib.mkIf config.foo {
    dendrites.systemonly.enable = true;
  };
}
