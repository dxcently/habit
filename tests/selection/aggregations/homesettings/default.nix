# A home half that carries a module beside its members, so the module's
# position among a user's other home modules is observable.
{
  description = "Select the homesettings aggregation.";

  home = {
    providers.notifications = "dunst";
    module = {
      fixture.marks = [ "aggregation" ];
    };
  };
}
