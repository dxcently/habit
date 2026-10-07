# A module whose own `imports` hold a file that writes `habit.home`: the wrapper
# reads the module's top-level `habit`, never its imports'.
{
  imports = [ ./nested.nix ];
}
