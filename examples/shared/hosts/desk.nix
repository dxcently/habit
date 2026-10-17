# examples/shared/hosts/desk.nix
{
  habit.dendrites.bar.enable = true;
  habit.dendrites.dock.enable = true;

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
