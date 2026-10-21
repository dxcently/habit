# examples/steps/7-shared/hosts/server/default.nix
{
  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  networking.hostName = "server";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
