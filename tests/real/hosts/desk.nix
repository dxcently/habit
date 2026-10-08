# tests/real/hosts/desk.nix — a NixOS host with two Home Manager users: the host
# selects for both, alice selects one more for herself and bob selects the home
# half of another alone.
{
  habit.dendrites = {
    zsh.enable = true;
    plain.enable = true;
    forced.enable = true;
    activation.enable = true;
    selected.enable = true;
    args.enable = true;
    gated.enable = true;
  };

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    dendrites.tmux.enable = true;
  };
  habit.users.bob = {
    definition = ../users/bob.nix;
    home.enable = true;
    dendrites.git = {
      enable = true;
      system = false;
    };
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
