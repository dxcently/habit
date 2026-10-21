# examples/steps/7-shared/modules/dendrites/shell/bash.nix
{
  programs.bash.completion.enable = true;

  habit.home = {
    programs.bash.enable = true;
  };
}
