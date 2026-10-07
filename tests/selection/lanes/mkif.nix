{ lib, ... }:
lib.mkIf true {
  sys.k = "s";
  habit.home.k = "h";
}
