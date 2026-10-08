# A `system` key in a module written inline in `imports` has the host's file
# name, so only its value, which selection does not hold, gives it away.
{
  imports = [ { habit.dendrites.systemonly.system = false; } ];
  habit.dendrites.systemonly.enable = true;
}
