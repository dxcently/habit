{ lib, ... }:
lib.mkOverride 10 {
  sys.k = "s";
  habit.home.k = "h";
}
