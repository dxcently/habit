# The imported file repeats the host's own selection: what it says is held, and
# it is still never read.
{
  imports = [ ./selectsInImport.nix ];
  habit.dendrites.systemonly.enable = true;
}
