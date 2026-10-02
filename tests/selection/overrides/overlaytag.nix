# Sets the attribute every lane, the caller and the nucleus set in
# `overlayOrder`, so the winner is the last overlay applied.
{
  dendrites = [ "laneone" ];
  overlay = _: _: { tag = "record"; };
}
