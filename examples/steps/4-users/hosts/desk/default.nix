# examples/steps/4-users/hosts/desk/default.nix
{
  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
    dendrites.shell.provider = "fish";
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
