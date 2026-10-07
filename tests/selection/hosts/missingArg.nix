# `modulesPath` is only in `imports`, which the scan drops, so the host scans
# although nothing provides the argument.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  habit.dendrites.systemonly.enable = true;
}
