# examples/full/hosts/alice/default.nix — a standalone home: its own selection, its own provider.
{
  habit.aggregation.base.enable = true;

  habit.dendrites.shell = {
    enable = true;
    provider = "fish";
  };

  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "26.11";
}
