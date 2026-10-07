# A standalone home has no users.
{
  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
  };
}
