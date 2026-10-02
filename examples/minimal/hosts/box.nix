# examples/minimal/hosts/box.nix
{
  dendrites.ssh.enable = true;

  nixos = {
    networking.hostName = "box";
  };
}
