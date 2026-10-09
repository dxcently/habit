# Changelog

Append-only. Newest first.

## 0.2.0

- A dendrite selection takes `system` (a bool, default `true`) in both scopes,
  `habit.dendrites.<name>.system` and `habit.users.<user>.dendrites.<name>.system`:
  `false` asks for the module's home half alone. The system half is applied iff
  at least one enabled selection of the module has `system = true`, and its
  `imports` are not evaluated otherwise; where the home half goes is unchanged.
  A group's members still write only `enable` and `provider`, so a host sets
  `habit.dendrites.<member>.system = false` on one. A home accepts the field and
  it changes nothing. A selection of a module or provider with no `habit.home`
  at `system = false` throws ``… selects only the home half of '<name>', which
  has none`` naming the host or user, the key and the file, and the host's
  own `system = false` on a host where no user has `home.enable` throws ``…
  selects only the home half of '<name>' but no user has home.enable``. An
  override record's `system` module follows its target's system half; its
  `overlay` and `home` module do not. The inventory shows each selection's
  `system`.
- A `mkIf` around a home half, at any depth above `habit.home`, is emitted
  outside the user's home module, as `home-manager.users.<user> = mkIf c <module>`,
  so the platform discharges it per definition: a false condition defines
  nothing in the user's Home Manager, and `mkIf false { habit.home.stylix = …; }`
  no longer fails as an option that does not exist where Home Manager has not
  declared `stylix`. A `mkOverride` is still carried to the leaves of the half's
  config inside the module. A condition may now cover a user's home half whole,
  its `imports` and option declarations too; in a standalone home, where there is
  no `home-manager.users`, conditions stay inside the home as in any Home Manager
  module and a half under one that carries `imports` or `options` is still
  refused.
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

- Added `tests/flake.nix` with its own `flake.lock`, run as
  `nix flake check ./tests`: Home Manager and nix-darwin are its inputs alone, so
  the root flake and its lock still hold nixpkgs only and a consumer's lock gains
  neither. Its cases (`tests/real/`) evaluate the real thing from
  `x86_64-linux` and each is a value read from the evaluation and the value it must
  equal: a NixOS host with two Home Manager users (host selection reaches both, a
  user's reaches that user alone, a plain and a `mkOverride` home half both
  arrive, a function-valued `habit.home` takes `lib.hm`, `habit.selected` holds
  each scope, the toplevel derivation evaluates), a standalone home through
  `homeManagerConfiguration` and `examples/home` (the system half is dropped, the
  caller's and a record's overlays apply, `system`, `host` and the caller's
  `specialArgs` reach modules, the activation package evaluates) and a
  nix-darwin host for `aarch64-darwin` (the system half applies, Home Manager's
  darwin module routes the home half and takes the home directory from the user
  module's `users.users.<user>.home`, the toplevel derivation evaluates, a
  Linux-only option fails and the module's file is the one the module system
  names). Nothing is built.
- A catalogue entry that is a directory is filed as the `default.nix` inside it,
  so an error that names the module, habit's own or the module system's (a
  NixOS-only option on nix-darwin), names that file and not the directory.

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
