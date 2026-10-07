{ config, lib, ... }:
lib.mkIf config.foo {
  habit.dendrites.systemonly.enable = true;
}
