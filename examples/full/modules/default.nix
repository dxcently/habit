# examples/full/modules/default.nix — the core registry; personal/ adds a second one.
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
    git = ./dendrites/git.nix;
    ssh = ./dendrites/ssh.nix;
  };
  aggregations = {
    base = ./aggregations/base;
    terminal = ./aggregations/terminal;
  };
  overrides = {
    zsh-quiet-compaudit = ./overrides/zsh-quiet-compaudit.nix;
  };
}
