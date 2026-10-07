# tests/real/overrides/plain-fix.nix — a record's overlay.
{
  dendrites = [ "plain" ];
  overlay = _final: _prev: {
    habitMark = "record";
    habitRecordOnly = "record";
  };
}
