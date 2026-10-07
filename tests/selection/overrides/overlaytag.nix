# Sets the attribute every lane and the caller set in
# `overlayOrder`, so the winner is the last overlay applied.
{
  dendrites = [ "laneone" ];
  overlay = _: _: { tag = "record"; };
}
