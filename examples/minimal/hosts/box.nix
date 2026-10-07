# examples/minimal/hosts/box.nix
{
  dendrites.ssh.enable = true;

  nixos = {
    networking.hostName = "box";
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.isContainer = true;
    system.stateVersion = "26.11";
  };
}
