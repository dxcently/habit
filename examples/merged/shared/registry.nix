# examples/merged/shared/registry.nix
{
  catalogue = {
    git = ./dendrites/git;
    ssh = ./dendrites/ssh;
  };
}
