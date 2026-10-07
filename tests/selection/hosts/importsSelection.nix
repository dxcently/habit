# The scan does not follow `imports`; the platform evaluation does.
{
  imports = [ ./selectsInImport.nix ];
  habit.dendrites.homeonly.enable = true;
}
