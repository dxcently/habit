# tests/real/dendrites/zsh.nix — both halves set a real option.
{
  programs.zsh.enable = true;

  habit.home.programs.zsh.enable = true;
}
