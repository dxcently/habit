# A condition cannot cover a home half's imports, so this is refused.
{ lib, ... }:
lib.mkIf true {
  habit.home.imports = [ { k = "i"; } ];
}
