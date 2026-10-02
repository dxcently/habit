# examples/merged/shared/dendrites/ssh/default.nix
{
  nixos = {
    services.openssh.enable = true;
  };
}
