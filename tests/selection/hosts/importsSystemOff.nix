# A `system` key in a file the host imports: the scan never sees it.
{
  imports = [ ./systemOffInImport.nix ];
  habit.dendrites.systemonly.enable = true;
}
