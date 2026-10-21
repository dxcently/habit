# examples/full/modules/personal/aggregations/dev/default.nix
{
  description = "Tools for working on the machine.";

  system = {
    members = [
      "ssh"
      "tmux"
    ];
  };
}
