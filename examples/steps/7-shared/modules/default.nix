# examples/steps/7-shared/modules/default.nix
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          imports = [ ./dendrites/shell/prompt.nix ];
          programs.fish.enable = true;
          habit.home = {
            imports = [ ./dendrites/shell/prompt-home.nix ];
            programs.fish.enable = true;
          };
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
