{ lib, ... }:
{
  options.fixture.declared = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config.fixture.declared = true;
}
