{ lib, ... }:
{
  config = lib.mkOrder 10 { sys.k = "s"; };
}
