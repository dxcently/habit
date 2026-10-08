# tests/real/registry.nix — the catalogue every real-platform case selects from.
# Most entries set options NixOS, nix-darwin and Home Manager all declare, so one
# registry serves the three. `bluetooth` and `udev` are Linux-only: one is a
# directory entry and one a file entry.
{
  catalogue = {
    zsh = ./dendrites/zsh.nix;
    tmux = ./dendrites/tmux.nix;
    plain = ./dendrites/plain.nix;
    forced = ./dendrites/forced.nix;
    activation = ./dendrites/activation.nix;
    selected = ./dendrites/selected.nix;
    args = ./dendrites/args.nix;
    gated = ./dendrites/gated.nix;
    bluetooth = ./dendrites/bluetooth;
    udev = ./dendrites/udev.nix;
  };

  aggregations = { };

  overrides = {
    plain-fix = ./overrides/plain-fix.nix;
  };
}
