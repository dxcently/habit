# examples/shared/registry.nix
{
  catalogue = {
    bar = ./dendrites/bar.nix;
    dock = ./dendrites/dock.nix;
  };
  aggregations = { };
}
