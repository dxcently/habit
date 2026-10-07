# examples/merged/hosts/box.nix
{
  habit.aggregation.dev.enable = true;
  habit.dendrites.ssh.enable = true;

  networking.hostName = "box";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
