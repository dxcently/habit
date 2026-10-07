{
  imports = [ ./setsHomeConfig.nix ];
  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
  };
}
