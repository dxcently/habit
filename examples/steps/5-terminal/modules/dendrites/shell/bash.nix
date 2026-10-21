# examples/steps/5-terminal/modules/dendrites/shell/bash.nix
{
  programs.bash.completion.enable = true;

  habit.home = {
    programs.bash.enable = true;
  };
}
