# examples/steps/5-terminal/modules/dendrites/terminal/foot.nix
{
  habit.home =
    { config, lib, ... }:
    let
      shell = config.habit.selected.shell;
    in
    {
      programs.foot = {
        enable = true;
        settings = lib.optionalAttrs shell.enable { main.shell = shell.provider; };
      };
    };
}
