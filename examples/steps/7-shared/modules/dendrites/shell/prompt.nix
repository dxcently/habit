# examples/steps/7-shared/modules/dendrites/shell/prompt.nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.starship ];
}
