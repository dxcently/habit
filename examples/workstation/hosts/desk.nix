# examples/workstation/hosts/desk.nix
{
  aggregation.desktop.enable = true;
  dendrites.printing.enable = false;

  users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    aggregation.desktop = {
      enable = true;
      notifications.provider = "dunst";
    };
  };

  nixos = {
    networking.hostName = "desk";
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.isContainer = true;
    system.stateVersion = "26.11";
  };
}
