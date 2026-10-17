# tests/real/providerRegistry.nix — the real registry plus one provider set written
# as a value. The host chooses `tmuxValue`, a module value; `zshFile`, a path, is
# not applied, and `thrown` is never read.
let
  registry = import ./registry.nix;
in
registry
// {
  catalogue = registry.catalogue // {
    shell = {
      providers = {
        zshFile = ./dendrites/zsh.nix;
        tmuxValue = {
          programs.tmux.enable = true;
        };
        thrown = throw "an unchosen provider was read";
      };
    };
  };
}
