# examples/minimal/dendrites/ssh/default.nix
{
  nixos = {
    services.openssh.enable = true;
  };
}
