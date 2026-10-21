# examples/full/modules/dendrites/ssh.nix
{
  services.openssh.enable = true;

  habit.home = {
    programs.ssh.enable = true;
  };
}
