# examples/steps/4-users/modules/default.nix
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
