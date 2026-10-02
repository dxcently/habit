# examples/minimal/dendrites/ssh.nix
{
  nixos = {
    services.openssh.enable = true;
  };
}
