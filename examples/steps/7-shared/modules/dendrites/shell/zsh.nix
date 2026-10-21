# examples/steps/7-shared/modules/dendrites/shell/zsh.nix
{ pkgs, ... }:
{
  imports = [ ./prompt.nix ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  habit.home = {
    imports = [ ./prompt-home.nix ];

    programs.zsh = {
      enable = true;
      shellAliases = import ./aliases.nix;
    };
  };
}
