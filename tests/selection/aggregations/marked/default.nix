# A system half whose module marks the platform, so its position in the module
# list is observable.
{
  description = "Select the marked aggregation.";

  system.module = {
    fixture.marks = [ "aggregation" ];
  };
}
