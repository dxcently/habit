# tests/real/hosts/valued.nix — a NixOS host that selects one generated value.
{
  habit.dendrites.tmux.enable = true;

  networking.hostName = "valued";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";
}
