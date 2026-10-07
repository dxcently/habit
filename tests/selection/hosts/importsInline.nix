# A module written inline in `imports` carries the host's own file name, so only
# what it selects gives it away.
{
  imports = [ { habit.dendrites.systemonly.enable = true; } ];
  habit.dendrites.homeonly.enable = true;
}
