# tests/real/users/alice.nix — an account on NixOS.
{
  users.users.alice.isNormalUser = true;

  habit.home.home.stateVersion = "26.11";
}
