# examples/steps/5-terminal/modules/default.nix
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
    terminal = {
      providers = {
        kitty = ./dendrites/terminal/kitty.nix;
        foot = ./dendrites/terminal/foot.nix;
      };
    };
  };
  aggregations = {
    terminal = ./aggregations/terminal;
  };
  overrides = { };
}
