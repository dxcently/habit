# A condition around a home half's imports: a user's platform discharges it
# whole, and a home that is itself the evaluation refuses it.
{ lib, ... }:
lib.mkIf true {
  habit.home.imports = [ { k = "i"; } ];
}
