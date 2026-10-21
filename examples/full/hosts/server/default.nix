# examples/full/hosts/server/default.nix
{
  habit.aggregation.base.enable = true;

  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  networking.hostName = "server";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
