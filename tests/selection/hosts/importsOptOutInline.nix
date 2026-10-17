# A user's opt-out written inline in `imports`: the scan never reads it, so the
# value, which selection does not hold, is what gives it away.
{
  imports = [ { habit.users.alice.dendrites.notifications.enable = false; } ];
  habit.dendrites.notifications = {
    enable = true;
    provider = "dunst";
  };
  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
  };
}
