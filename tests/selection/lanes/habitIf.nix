{ lib, ... }:
{
  habit = lib.mkIf true { home.k = "h"; };
}
