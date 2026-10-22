# A group with one member, the throwing landmine: a host that switches that
# member off never imports it, and one that does not switch it off does.
{
  description = "Select the group whose member a host may switch off.";

  system.members = [ "landmine" ];
}
