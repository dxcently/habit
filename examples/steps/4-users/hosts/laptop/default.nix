# examples/steps/4-users/hosts/laptop/default.nix
{
  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
    dendrites.shell = {
      enable = true;
      provider = "fish";
    };
  };

  networking.hostName = "laptop";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
