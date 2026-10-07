# The minimal example's host with its selection moved into an imported file.
{
  imports = [ ./selectsSshInImport.nix ];

  networking.hostName = "box";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
