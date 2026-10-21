# examples/steps/2-home/hosts/desk/default.nix
{
  habit.dendrites.shell.enable = true;

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
