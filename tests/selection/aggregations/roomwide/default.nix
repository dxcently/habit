# A group whose home half names a dendrite with no home half of its own, so the
# system half a host-sent home member brings is observable alone.
{
  description = "Select the roomwide aggregation.";

  home.members = [ "systemonly" ];
}
