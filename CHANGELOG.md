# Changelog

Append-only. Newest first.

## v2

- Removed the constructor's `nucleus` argument. An unconditional module goes in
  `extraModules`; the dendrites every host carries are, by convention, the members
  of an aggregation named `nucleus` that each host selects and may deselect
  from. A caller that still passes `nucleus` now fails with Nix's
  unexpected-argument error.
- A dendrite, a provider file and a user definition are plain modules, read
  through `lib/lanes.nix`: the module's own settings are its system half and
  `habit.home` is its home half. A lane record (`{ body; nixos; homeManager; }`)
  is no longer read; it fails where the host's system half is evaluated, as an
  option that does not exist, naming the file. The "exposes no <lane> lane"
  errors, the account-lane error and the whole-tree refusal are gone, and so
  are `lanesFor` and `laneNames` from the constructor's exports; `implOf`
  returns `{ path; label }`.
- Where a selected module's halves go: the host's selection applies the system
  half and sends the home half to every user with `home.enable = true`; a user's
  selection applies the system half too and sends the home half to that user
  alone; a module reached both ways reaches that user once. One system takes
  one implementation of a capability, so the host and users that select it with
  different providers are an error naming every claimant. The home half is a
  `home-manager.users.<user>` definition, emitted only for a non-empty set of
  users. Home settings a user module wrote as a `homeManager` lane are now
  `habit.home`.
- Added `habit.selected.<name>`, `{ enable; provider; }` for every catalogue
  name, a read-only option in the host's evaluation and in each user's home,
  each holding its own scope's selection.
- Renamed, with no old spelling kept: an override record's `nixos` and
  `homeManager` are `system` and `home` (and `overridesFor` returns those, a
  record's `home` module riding the users its target's home half reaches); an
  aggregation half's `nixos` and `homeManager` are `module`; a user's
  `homeManager.enable` and `homeManager.config` are `home.enable` and
  `home.config`; the inventory's `users.<user>.homeManager` is `home`, and the
  stranded-home error reads `home.enable = false`.
- The module list gains `habit.selected` for the system, and each user module
  and each selected capability as a wrapped module in the lanes' old places;
  the whole-tree check on `extraModules` is gone, so a catalogue file both
  selected and imported by hand is nixpkgs's `already declared`.

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
- Aggregation bodies are validated when read: a body that is not an attrset, an
  unknown key at the top of a body or in a half, and a half that is not an
  attrset throw, naming the aggregation and its file, and the key, or the body
  or half and its type.
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
