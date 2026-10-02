# examples/workstation/dendrites/notifications/default.nix — two providers;
# only the chosen file is ever read.
{
  providers = {
    dunst = ./dunst.nix;
    mako = ./mako.nix;
  };
}
