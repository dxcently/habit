# tests/real/hosts/providerSet.nix — a NixOS host that chooses one provider of a
# provider set written as a value.
{
  habit.dendrites.shell = {
    enable = true;
    provider = "tmuxValue";
  };

  networking.hostName = "providerSet";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";
}
