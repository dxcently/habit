{ lib, ... }:
{
  freeformType = lib.types.lazyAttrsOf lib.types.anything;
  meta.note = "kept";
  config.free.x = "a";
}
