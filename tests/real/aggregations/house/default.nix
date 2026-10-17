# tests/real/aggregations/house — a group whose home half is git's home
# configuration. A host selects it for every user with a home; a user opts out.
{
  description = "Select the house aggregation.";

  home.members = [ "git" ];
}
