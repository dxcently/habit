{ lib, ... }:
lib.mkIf false {
  sys.k = "s";
  habit.home.k = "h";
}
