# examples/steps/6-override/modules/dendrites/shell/zsh.nix
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
