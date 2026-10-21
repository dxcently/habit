# examples/steps/3-providers/modules/dendrites/shell/bash.nix
{
  programs.bash.completion.enable = true;

  habit.home = {
    programs.bash.enable = true;
  };
}
