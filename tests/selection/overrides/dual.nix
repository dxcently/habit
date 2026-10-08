# Targets a capability with both halves and carries an overlay, a system module
# and a home module: the system module follows the system half, the overlay
# any selection.
{
  dendrites = [ "notifications" ];
  overlay = _final: _prev: { fixture-dual = "patched"; };
  system = _: { fixture.marks = [ "dualsystem" ]; };
  home = _: { fixture.marks = [ "dualhome" ]; };
}
