# Sets the attribute every selected module and the caller set in
# `overlayOrder`, so the winner is the last overlay applied.
{
  dendrites = [ "overlayone" ];
  overlay = _: _: { tag = "record"; };
}
