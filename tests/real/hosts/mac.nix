# tests/real/hosts/mac.nix — a nix-darwin host with one Home Manager user.
{
  habit.dendrites = {
    zsh.enable = true;
    plain.enable = true;
    selected.enable = true;
    args.enable = true;
  };

  habit.users.alice = {
    definition = ../users/alice-darwin.nix;
    home.enable = true;
    dendrites.tmux.enable = true;
  };

  networking.hostName = "mac";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}
