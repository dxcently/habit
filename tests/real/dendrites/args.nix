# tests/real/dendrites/args.nix — the arguments a builder hands every module:
# the host's name, its system and what the caller passed in `specialArgs`.
{
  host,
  system,
  greeting,
  ...
}:
{
  environment.variables.SYSTEM_ARGS = "${system}/${host}/${greeting}";

  habit.home =
    {
      host,
      system,
      greeting,
      ...
    }:
    {
      home.sessionVariables.HOME_ARGS = "${system}/${host}/${greeting}";
    };
}
