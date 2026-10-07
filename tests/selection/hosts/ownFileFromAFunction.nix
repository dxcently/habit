{ lib, ... }:
{
  _file = "the host's own name";
  habit.dendrites.systemonly.enable = lib.mkForce true;
}
