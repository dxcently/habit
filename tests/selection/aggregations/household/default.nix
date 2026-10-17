# A group with a member in each half, and a home module, so a host's selection
# of it is observable in the system and in each user's home.
{
  description = "Select the household aggregation.";

  system.members = [ "systemonly" ];

  home = {
    members = [ "homeonly" ];
    module = {
      fixture.marks = [ "household" ];
    };
  };
}
