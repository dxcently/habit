{ lib, ... }:
{
  require = [ { out.required = "r"; } ];
  out.short = "s";
  environment.tag = lib.mkDefault "t";
}
