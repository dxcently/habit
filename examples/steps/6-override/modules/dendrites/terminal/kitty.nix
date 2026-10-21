# examples/steps/6-override/modules/dendrites/terminal/kitty.nix
{
  habit.home =
    { config, lib, ... }:
    let
      shell = config.habit.selected.shell;
    in
    {
      programs.kitty = {
        enable = true;
        settings = lib.optionalAttrs shell.enable { shell = shell.provider; };
      };
    };
}
