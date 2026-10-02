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
  field. Each source must be an attrset with a unique string `name`, takes only `name`,
  `catalogue`, `aggregations` and `overrides` (any other field throws), and a
  field it carries must be an attrset.
- An override record's overlays are applied after the lanes' and before the
  caller's and the nucleus's: a record beats a lane on a shared attribute, and
  the consumer's own overlays keep the last word.
- Aggregation bodies are validated when read: an unknown key at the top of a
  body or in a half, and a half that is not an attrset, throw naming the
  aggregation, its file and the key.
- `checks.x86_64-linux.selection` runs the suite.
- Added `examples/` (`minimal`, `workstation`, `merged`), each evaluated by the
  suite for its inventory, its module list and real NixOS option values, and
  run the suite against the dummy store when `HABIT_LIB` is given.
- Added `docs/`, the reference as an mdBook: the two passes, dendrites,
  aggregations, the host record, override records, the constructor, merging
  registries, errors and comparisons. `checks.x86_64-linux.docs` checks every
  quoted example file against the file (`tests/docs/quotes.sh`) and builds the
  book; `.github/workflows/pages.yml` publishes it. `README.md` is the short
  entry point.
