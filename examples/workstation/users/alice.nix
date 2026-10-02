# examples/workstation/users/alice.nix
{
  nixos = {
    users.users.alice.isNormalUser = true;
  };
  homeManager = {
    home.stateVersion = "26.11";
  };
}
