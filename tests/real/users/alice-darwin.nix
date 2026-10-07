# tests/real/users/alice-darwin.nix — an account on nix-darwin. Home Manager
# takes the home's directory from `users.users.<user>.home` there.
{
  users.users.alice.home = "/Users/alice";

  habit.home.home.stateVersion = "26.11";
}
