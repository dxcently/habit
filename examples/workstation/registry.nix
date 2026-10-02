# examples/workstation/registry.nix
{
  catalogue = {
    bluetooth = ./dendrites/bluetooth;
    notifications = ./dendrites/notifications;
    printing = ./dendrites/printing;
  };
  aggregations = {
    desktop = ./aggregations/desktop;
  };
}
