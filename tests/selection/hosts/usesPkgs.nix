{ pkgs, ... }:
{
  habit.dendrites.systemonly.enable = pkgs.stdenv.isLinux;
}
