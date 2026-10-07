{ username, ... }:
{
  habit.users.${username} = {
    definition = ../users/alice.nix;
    home.enable = true;
  };
}
