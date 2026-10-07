# A system half only NixOS declares, beside a home half. Where there are no
# `services` (a home, darwin) the system half is the one that fails when it is
# applied, and a home drops it.
{
  services.openssh.enable = true;
  habit.home.fixture.marks = [ "linuxOnly" ];
}
