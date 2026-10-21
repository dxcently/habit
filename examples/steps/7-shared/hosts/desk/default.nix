# examples/steps/7-shared/hosts/desk/default.nix
{
  habit.aggregation.terminal.enable = true;

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
  };

  habit.users.bob = {
    definition = ../../users/bob.nix;
    home.enable = true;
    dendrites.shell.enable = false;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
