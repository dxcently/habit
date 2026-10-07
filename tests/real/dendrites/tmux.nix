# tests/real/dendrites/tmux.nix — both halves set a real option.
{
  programs.tmux.enable = true;

  habit.home.programs.tmux.enable = true;
}
