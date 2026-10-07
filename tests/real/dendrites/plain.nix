# tests/real/dendrites/plain.nix — a plain home half.
{
  habit.home = {
    home.sessionVariables.PLAIN = "1";
    home.language.base = "plain";
  };
}
