# Targets a home-only capability and carries both halves: the overlay is still
# host-scoped — `useGlobalPkgs` means a home configuration draws from the host
# package set — while the home module rides only the users who selected it.
{
  dendrites = [ "notifications" ];
  overlay = _final: _prev: { fixture-homely = "patched"; };
  home = _: { fixture.marks = [ "homely" ]; };
}
