# examples/merged/hosts/box.nix
{
  aggregation.dev.enable = true;
  dendrites.ssh.enable = true;

  nixos = {
    networking.hostName = "box";
  };
}
