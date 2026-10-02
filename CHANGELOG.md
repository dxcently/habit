# Changelog

Append-only. Newest first.

## v1

- Extracted `lib/composition.nix` from Aoide (`1239a83d333cde0b4a3d7bc28e6c8a989093b92d`,
  `lib/composition.nix`) with no change of behaviour; comments naming Aoide
  paths and documents now say what is true here.
- Ported Aoide's selection suite (`tests/selection`) against this repo's own
  `lib/composition.nix`. The cases for `lib/songbook.nix` and `lib/pkgs.nix`
  stay in Aoide: those files are not part of habit.
- Added `lib/catalogues.nix`: `mergeRegistries` merges sources into one
  registry and throws on any name more than one source defines, naming the
  field. Each source needs a unique string `name`, and a field it carries
  must be an attrset.
- `checks.x86_64-linux.selection` runs the suite.
