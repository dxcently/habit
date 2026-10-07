# examples/workstation/hosts/desk.nix
{
  habit.aggregation.desktop.enable = true;
  habit.dendrites.printing.enable = false;

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    aggregation.desktop = {
      enable = true;
      notifications.provider = "dunst";
    };
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
