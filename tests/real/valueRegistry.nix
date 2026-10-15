# tests/real/valueRegistry.nix — the real registry plus one module value per name
# in a list: a family generated the way a consumer generates one entry per
# package. Only `tmux` is selected by the host, so `htop` is never applied.
let
  registry = import ./registry.nix;
  generated = name: {
    programs.${name}.enable = true;
  };
in
registry
// {
  catalogue =
    registry.catalogue
    // builtins.listToAttrs (
      map (name: {
        inherit name;
        value = generated name;
      }) [ "htop" "tmux" ]
    );
}
