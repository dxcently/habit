# tests/real/hosts/home.nix — a standalone home: its host module is the home.
{
  habit.dendrites = {
    zsh.enable = true;
    plain.enable = true;
    forced.enable = true;
    activation.enable = true;
    selected.enable = true;
    args.enable = true;
  };

  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "26.11";
}
