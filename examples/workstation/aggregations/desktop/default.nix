# examples/workstation/aggregations/desktop/default.nix
{
  description = "A machine someone sits at.";

  system = {
    members = [
      "bluetooth"
      "printing"
    ];
    nixos = {
      services.xserver.xkb.layout = "us";
    };
  };

  home = {
    providers.notifications = "mako";
  };
}
