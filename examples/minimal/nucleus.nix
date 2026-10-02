# examples/minimal/nucleus.nix — what every host carries, selected or not.
{
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
