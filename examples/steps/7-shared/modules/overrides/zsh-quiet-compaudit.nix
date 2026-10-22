# examples/steps/7-shared/modules/overrides/zsh-quiet-compaudit.nix
{
  dendrites = [ "shell" ];

  system = {
    environment.variables.ZSH_DISABLE_COMPFIX = "true";
  };
}
