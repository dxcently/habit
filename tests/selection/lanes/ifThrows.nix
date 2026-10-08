# A condition that cannot be forced, over a home half.
{ lib, ... }:
lib.mkIf (throw "the condition was forced") {
  sys.k = "s";
  habit.home.k = "h";
}
