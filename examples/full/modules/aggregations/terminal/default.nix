# examples/full/modules/aggregations/terminal/default.nix
{
  description = "A terminal, and the shell it launches.";

  system = {
    providers = {
      shell = "zsh";
      terminal = "kitty";
    };
  };

  home = {
    providers = {
      shell = "zsh";
      terminal = "kitty";
    };
  };
}
