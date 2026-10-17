# tests/real/aggregations/den — a group whose home half is one home-only dendrite,
# so it evaluates on nix-darwin, which has no `programs.git`.
{
  description = "Select the den aggregation.";

  home.members = [ "forced" ];
}
