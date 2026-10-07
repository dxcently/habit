# examples/home/hosts/alice.nix
{
  habit.dendrites.ssh.enable = true;

  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "26.11";
}
