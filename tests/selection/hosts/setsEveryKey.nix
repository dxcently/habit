# Each key the host writes under `habit` is declared in the platform evaluation
# too, and holds there what the scan read.
{
  habit.dendrites.notifications = {
    enable = true;
    provider = "dunst";
  };
  habit.aggregation.workstation = {
    enable = true;
    notifications.provider = "herald";
  };
  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    dendrites.homeonly.enable = true;
    aggregation.desk.enable = true;
  };
}
