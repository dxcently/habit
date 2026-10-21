# examples/steps/2-home/modules/dendrites/shell/default.nix
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  habit.home = {
    programs.zsh = {
      enable = true;
      shellAliases = import ./aliases.nix;
    };
  };
}
