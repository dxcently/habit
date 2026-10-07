# Throws when the host's imports are followed: the scan never does, the
# platform evaluation always does.
{
  imports = [ ./importThrows.nix ];
  habit.dendrites.systemonly.enable = true;
}
