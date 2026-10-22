# examples/full/modules/personal/default.nix — a second registry; `dev` groups `git`, from the core registry, and `tmux`, which lives here.
{
  catalogue = {
    tmux = ./dendrites/tmux.nix;
  };
  aggregations = {
    dev = ./aggregations/dev;
  };
  overrides = { };
}
