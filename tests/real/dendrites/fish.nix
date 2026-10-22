# tests/real/dendrites/fish.nix — the fish provider: both halves set a real option.
{
  programs.fish.enable = true;

  habit.home.programs.fish.enable = true;
}
