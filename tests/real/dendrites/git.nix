# tests/real/dendrites/git.nix — both halves set a real option, so a selection can
# ask for the home half alone.
{
  programs.git.enable = true;

  habit.home.programs.git.enable = true;
}
