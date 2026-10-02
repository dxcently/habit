# examples/merged/personal/registry.nix — `dev` groups a capability this
# source does not define; the merged registry is where the name resolves.
{
  catalogue = {
    tmux = ./dendrites/tmux;
  };
  aggregations = {
    dev = ./aggregations/dev;
  };
}
