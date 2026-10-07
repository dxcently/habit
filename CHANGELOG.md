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

- The host is one module, passed as `host` (a path or a module value) in place of
  `hostModules`. The typed host record and its deferred `nixos` field are gone:
  the module goes into the platform's module list as its last entry, and what it
  sets besides `habit` is the host's own platform configuration. Its selection keys
  moved under `habit`: `habit.dendrites.<name>.{enable,provider}`,
  `habit.aggregation.<group>…` and `habit.users.<user>.{definition,home,dendrites,aggregation}`.
  A caller that still passes `hostModules` fails with Nix's unexpected-argument
  error, and a host that still writes `dendrites.<name>` at the top level fails as
  an option that does not exist, naming the file.
- Selection reads the host through `lib/scan.nix`: the host is applied to the
  caller's `specialArgs` with `config`, `pkgs`, `options` and `osConfig` replaced
  by values that throw, its `imports` are dropped and every other key is never
  forced. A `habit` key that needs one of those four arguments is refused, naming
  the host file and the argument; an argument the host takes that `specialArgs`
  does not hold is named when the host reads it, so `modulesPath` used only under
  `imports` costs nothing; the caller's own `lib` is the host's `lib`; a typo such
  as `habit.dendrtes` is an option that does not exist, with the nearest names
  suggested.
- The platform evaluation declares the host's `habit.*` keys inert (null until
  written) and fails every key the scan did not see: any `habit` key written by a
  file other than the host's, and any key written inline in the host's own
  `imports` whose value selection does not hold. That is how a selection, a hook's
  key or a user's `home.config` written in a file the host imports, where the scan
  does not look, is caught: "`habit.dendrites.kitty.enable` is set in <file> but
  the host scan never saw it (scans do not follow `imports`)".
- `selectionModules` are modules of `habit`: an option one declares is
  `habit.<option>`, the host sets it there, the platform evaluation declares it
  too, and the resolved selection (what `extraModulesFor` receives, and
  `evalSelection` returns) is the `habit` option's value, so a hook's field is
  `selection.<option>`. `dendrites`, `aggregation`, `users`, `selected` and `home`
  are reserved: a module declaring one fails, naming its file. `evalSelection`
  takes `{ registry, host, specialArgs, selectionModules }`.
- An aggregation's system `module` is its own module-list entry just before the
  host module, and a home half's `module` is imported just before the user's
  `home.config`; both used to merge into a deferred module (`selection.nixos`,
  `home.config`), and are now read from the body when the list is assembled.
- Invariants 1 and 5 of `AGENTS.md` are reworded: selection never reads platform
  values (it reads the host module's literal `habit.*` and nothing else), and the
  constructor knows no consumer's vocabulary (it knows habit's own words).

- One core, `mkModules { class; … }`, serves three classes, each with a thin
  builder that takes the evaluator's flake from the caller (habit reads no input):
  `mkNixosHost` (`nixpkgs`, as before), `mkDarwinHost` (`darwin`, calling
  `darwin.lib.darwinSystem`) and `mkHome` (`home-manager` and `pkgs`, calling
  `home-manager.lib.homeManagerConfiguration { pkgs; modules; extraSpecialArgs; }`
  and returning `{ home, selection, inventory }`). `mkNixosModules` is
  `mkModules` with the class set, and returns the module list as before. A class
  not among `nixos`, `darwin` and `home` is refused by name.
- A darwin host is a nix-darwin module built exactly as a NixOS host is, with
  Home Manager's darwin module as `homeManagerModule`. habit declares nothing
  about whether a module supports darwin: a NixOS-only option fails as the module
  system's own error naming the module's file.
- A standalone home is a Home Manager module that is its own host module. Its
  scope is `home`: every selected module's system half is dropped, `imports` with
  it, and its home half is imported into the home itself; `habit.aggregation`
  selects a group's `home` half; `habit.selected` is the home's own; a matched override record applies its
  `overlay` and its `home` module, and `overridesFor` returns the latter as
  `standalone`. `habit.users` in a home host is refused, naming the file.
  `mkSchema` and `evalSelection` take `scope` (default `system`), which hook
  modules receive as their `scope` argument.
- A home half is always a plain module, in every class: for a user it is the
  definition of `home-manager.users.<user>`, in a home an import, and a `mkIf`,
  `mkMerge` or `mkOverride` around `habit.home` or around the module's config is
  carried down to the leaves of its `config`. Before, such a wrapper sat on the
  user's definition, where the users type filters definitions by priority, so a
  module whose `habit.home` was under `mkOverride` silently dropped every other
  module's home half for that user. A condition covers what the half sets, not
  its `imports` or `options`, which are read before any condition is: a half
  under a condition that carries either is refused, naming the module. A
  `habit.home` that is not a module (`5`) is refused naming the file and
  `habit.home`; a path is the module it names.
- `homeManagerModule` is optional: a user with `home.enable = true` and none
  given is an error naming the host, and a home given one is an error too,
  since Home Manager is its evaluator.
- Added `examples/home`: a standalone home selecting a module whose system half
  a home drops.

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
