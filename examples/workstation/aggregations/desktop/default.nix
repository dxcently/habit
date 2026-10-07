# examples/workstation/aggregations/desktop/default.nix
{
  description = "A machine someone sits at.";

  system = {
    members = [
      "bluetooth"
      "printing"
    ];
    module = {
      services.xserver.xkb.layout = "de";
    };
  };

  home = {
    providers.notifications = "mako";
  };
}
