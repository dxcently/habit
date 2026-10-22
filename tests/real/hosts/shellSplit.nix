# tests/real/hosts/shellSplit.nix — the host picks zsh for the system; alice picks
# fish for her home alone, and bob takes the host's zsh.
{
  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    dendrites.shell.provider = "fish";
  };
  habit.users.bob = {
    definition = ../users/bob.nix;
    home.enable = true;
  };

  networking.hostName = "shellSplit";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
