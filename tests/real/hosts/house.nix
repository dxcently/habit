# tests/real/hosts/house.nix — a NixOS host that selects a group for the homes of
# all its users; bob opts out of the group's home half.
{
  habit.aggregation.house.enable = true;

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
  };
  habit.users.bob = {
    definition = ../users/bob.nix;
    home.enable = true;
    aggregation.house.enable = false;
  };

  networking.hostName = "house";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
