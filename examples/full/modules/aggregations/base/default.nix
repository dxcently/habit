# examples/full/modules/aggregations/base/default.nix
{
  description = "What every machine here carries: ssh, for the system and for each home.";

  system = {
    members = [ "ssh" ];
  };

  home = {
    members = [ "ssh" ];
  };
}
