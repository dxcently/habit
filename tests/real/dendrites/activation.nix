# tests/real/dendrites/activation.nix — a function-valued home half takes Home
# Manager's own `lib`, which carries `lib.hm`; the module's head has the system's.
{
  habit.home =
    { lib, ... }:
    {
      home.activation.habitFixture = lib.hm.dag.entryAfter [ "writeBoundary" ] "true";
    };
}
