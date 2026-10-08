# A false condition over a home half that sets an option the platform does not
# declare.
{ lib, ... }:
lib.mkIf false {
  habit.home.undeclared = "h";
}
