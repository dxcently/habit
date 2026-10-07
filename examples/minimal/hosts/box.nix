# examples/minimal/hosts/box.nix
{
  habit.dendrites.ssh.enable = true;

  networking.hostName = "box";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
