# examples/steps/6-override/modules/overrides/zsh-quiet-compaudit.nix
{
  dendrites = [ "shell" ];

  system = {
    environment.variables.ZSH_DISABLE_COMPFIX = "true";
  };
}
