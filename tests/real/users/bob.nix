# tests/real/users/bob.nix — an account on NixOS.
{
  users.users.bob.isNormalUser = true;

  habit.home.home.stateVersion = "26.11";
}
