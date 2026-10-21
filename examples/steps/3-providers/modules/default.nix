# examples/steps/3-providers/modules/default.nix
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          programs.fish.enable = true;
          habit.home.programs.fish.enable = true;
        };
      };
    };
  };
  aggregations = { };
  overrides = { };
}
