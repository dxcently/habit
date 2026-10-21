# Two entries that share one piece, selected by a host with one user who has a home.
{
  habit.dendrites.bar.enable = true;
  habit.dendrites.dock.enable = true;

  habit.users.alice = {
    definition = ./alice.nix;
    home.enable = true;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
