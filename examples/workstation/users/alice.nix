# examples/workstation/users/alice.nix
{
  users.users.alice.isNormalUser = true;

  habit.home = {
    home.stateVersion = "26.11";
  };
}
