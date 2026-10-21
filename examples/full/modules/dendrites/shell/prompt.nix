# examples/full/modules/dendrites/shell/prompt.nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.starship ];
}
