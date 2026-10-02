# examples/merged/personal/aggregations/dev/default.nix
{
  description = "Tools for working on code.";

  system.members = [
    "git"
    "tmux"
  ];
}
