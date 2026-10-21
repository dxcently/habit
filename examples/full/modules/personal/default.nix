# examples/full/modules/personal/default.nix — a second registry; `dev` groups `ssh`, which only the core registry defines.
{
  catalogue = {
    tmux = ./dendrites/tmux.nix;
  };
  aggregations = {
    dev = ./aggregations/dev;
  };
  overrides = { };
}
