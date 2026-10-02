# examples/workstation/hosts/desk.nix
{
  aggregation.desktop.enable = true;
  dendrites.printing.enable = false;

  users.alice = {
    definition = ../users/alice.nix;
    homeManager.enable = true;
    aggregation.desktop = {
      enable = true;
      notifications.provider = "dunst";
    };
  };

  nixos = {
    networking.hostName = "desk";
  };
}
