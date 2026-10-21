# examples/steps/1-file/hosts/desk/default.nix
{
  habit.dendrites.shell.enable = true;

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
