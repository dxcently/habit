# Comparisons

habit answers one question: which modules does this host import? This page
sets it beside four projects that answer it differently: den, the dendritic
pattern with flake-parts, snowfall-lib and blueprint. Each claim about another
project was checked against its source at the revision named in its section;
file paths there are relative to that repository. habit is described from this
repository's code and tests.

## What only habit does

None of the four does any of these, in the setups each project documents.

| habit | elsewhere | shown in |
| ----- | --------- | -------- |
| A host drops one member of a shared group with `enable = false`, and any later layer brings it back with `mkForce true` | den removes with `excludes`, an append-only list; a dendritic group is a plain `imports` list; snowfall-lib and blueprint have no groups | [Aggregations](aggregations.md#membership-is-mkdefault); [den](#den), [dendritic and flake-parts](#dendritic-and-flake-parts) |
| A member a host switched off is never imported, and the suite proves it with a file that throws on import | den does not apply an excluded aspect, but the aspect is a definition in the module graph: in den's template, import-tree loads the file that declares it; `disabledModules` loads a module before removing it; snowfall-lib imports every module into every system; blueprint has no members to switch off | [The two passes](two-passes.md#the-evaluation-boundary); [den](#den), [dendritic and flake-parts](#dendritic-and-flake-parts), [snowfall-lib](#snowfall-lib) |
| Each host's inventory names every capability, its provider and the path it came from | den lists aspect identities with no paths; the others record nothing | [The constructor](constructor.md#the-inventory); [den](#den) |
| A name defined by two merged sources is an error naming both | `den.aspects` and `flake.modules` merge the two definitions into one | [Merging registries](merging.md#errors); [den](#den), [dendritic and flake-parts](#dendritic-and-flake-parts) |

## den

Checked at vic/den `7594405`.

den's content unit is the aspect, declared under `den.aspects.<name>`: an
attrset whose class keys (`nixos`, `darwin`, `homeManager`) emit modules into
entities of that class. Hosts, users and homes are entities. Aspects pull
others in with `includes` and remove them from a subtree with `excludes`;
policies and `provides` route configuration across entities
(`AGENTS.md`, "Core concepts"; `docs/src/content/docs/reference/aspects.mdx`).

What the differences mean for you:

- **A removal cannot be taken back downstream.** `excludes` merges as
  `acc ++ …`, list concatenation (`modules/options.nix`). Once a shared layer
  excludes `kitty`, every layer below it has lost `kitty`, and giving one host
  its member back means reshaping the aspects. In habit removal is a boolean
  merged by priority: `dendrites.kitty.enable = false` beats the group's
  `mkDefault`, and `mkForce true` beats that.
- **Excluded is not unread.** den does not apply an excluded aspect, but an
  aspect is a definition under `den.aspects`, and den's own template loads every
  file under `modules/` with import-tree (`templates/minimal/flake.nix`). The
  file declaring an excluded aspect is part of the evaluation that builds every
  host. habit's catalogue holds paths, and an unselected one is never imported.
- **The inventory names identities, not files.** `entity.aspects` lists
  resolved aspects with `.identity`, `.identityKey` and `.isNamed`, and lists
  anonymous aspects too
  (`docs/src/content/docs/explanation/structural-introspection.mdx`). To learn
  which file an aspect came from, you search. habit's inventory records the
  `source` path of each capability.
- **A duplicate name merges.** `den.aspects` is a submodule with a freeform
  `lazyAttrsOf` (`nix/lib/aspects/types.nix`, `aspectsType`), so two files
  defining one name become one aspect; only a conflicting option value surfaces,
  later, in NixOS. Across habit sources, `mergeRegistries` throws naming both.

What den has that habit does not: darwin hosts (`den.classes` registers
`darwin`, and a darwin-system host becomes a `darwinConfigurations` entry,
`modules/options.nix`, `docs/src/content/docs/guides/declare-hosts.mdx`),
standalone homes (`den.homes.<system>.<name>`,
`docs/src/content/docs/guides/standalone-home-manager.mdx`), parametric aspects
that are functions of `{ host, user }` (`README.md`), and routing between
entities. It runs with or without flake-parts (`modules/outputs.nix` branches
on its presence).

## dendritic and flake-parts

Checked at mightyiam/dendritic `6c76240` and hercules-ci/flake-parts `024633c`.

The dendritic pattern makes every file a module of one top-level
configuration and stores lower-level modules (NixOS, Home Manager, darwin) as
option values in it. That configuration is "commonly" flake-parts, "but it
does not have to be" (`README.md`). flake-parts provides the option for it,
`flake.modules`, typed `lazyAttrsOf (lazyAttrsOf deferredModule)` and keyed by
class, then name (`extras/modules.nix`).

What the differences mean for you:

- **A group cannot lose a member.** A group is a module whose `imports` lists
  others, and `imports` is a plain list in the module system, with no priority.
  A host that wants a group minus one member gets a second group.
- **`disabledModules` patches the result; it does not select.** In nixpkgs
  `e554fab` (this repository's pin), `lib/modules.nix`
  `collectStructuredModules` loads every module and its `imports` and gathers
  each `disabledModules` entry on the way; `filterModules` removes the disabled
  modules only afterwards. A disabled module has been loaded by then, and what
  it imports is still collected.
- **A duplicate name merges, by design.** `deferredModule` values merge under
  one name, which the pattern advertises ("Lower-level module merging",
  `README.md`). Two files that both define `flake.modules.nixos.ssh` give one
  module combining both, without a word. Across habit sources, that is an error.
- **Nothing records what a host resolved.** A host's configuration is whatever
  its `imports` reached.

What it has that habit does not: classes are free-form names, so darwin and
Home Manager modules are published the same way; and flake-parts is a general
flake framework with "an ecosystem of modules that you can import"
(`README.md`). habit does not replace it: a flake-parts flake can call
`mkNixosHost` like any other flake.

## snowfall-lib

Checked at snowfallorg/lib `6ee3542`.

snowfall-lib turns a directory layout into flake outputs: `systems/`,
`homes/`, `modules/nixos`, `modules/darwin` and more, read with `readDir`
(`snowfall-lib/fs/default.nix`). It builds on flake-utils-plus (`flake.nix`).

What the difference means for you: every module under `modules/nixos` is in
every NixOS system's module list. `create-systems` takes
`builtins.attrValues user-modules` into each system's `modules`
(`snowfall-lib/system/default.nix`). Each module has to gate itself, typically
with an option and `mkIf`, and its option declarations are on every host
whether it is used there or not: the import-everywhere shape
[the two passes](two-passes.md) exist to avoid. There are no groups to take
minus a member and no record of what a host resolved. Names are paths in one
tree, so there is no cross-source clash to catch.

What it has that habit does not: no registry to write, since a new directory is
a new host, home or module; darwin systems (`modules/darwin`, the darwin branch
of `snowfall-lib/system/default.nix`); and standalone homes
(`homeConfigurations`, `snowfall-lib/home/default.nix`).

## blueprint

Checked at numtide/blueprint `8be7524`.

blueprint maps folders to flake outputs one to one: `hosts/` to
`nixosConfigurations` and `darwinConfigurations`, `modules/` to `nixosModules`
and `darwinModules` (`README.md`), discovered with `readDir` (`lib/default.nix`).
A user under `hosts/<host>/users/<user>` also becomes a standalone
`homeConfigurations."<user>@<host>"` (`lib/default.nix`). It does not build on
flake-parts; its README lists it as a related project.

What the difference means for you: blueprint has no groups or selection. A
host's configuration imports the modules it names, which is the plain module
system, and simple. A group shared across hosts is a module whose `imports`
lists its members, which brings back the plain list of
[dendritic and flake-parts](#dendritic-and-flake-parts): no member can be
switched off for one host. Nothing records what each host resolved.

What it has that habit does not: discovery with no registry to write, darwin
hosts and standalone homes.

## When to pick something else

- **darwin hosts or standalone Home Manager.** den, snowfall-lib and blueprint
  build both. habit builds NixOS hosts, with Home Manager as the NixOS module.
- **No registry at all.** snowfall-lib and blueprint discover hosts, modules
  and homes from the directory layout. habit's registry is written by hand or
  generated by the consumer.
- **A general flake framework.** flake-parts structures a whole flake and has
  an ecosystem of modules. habit is one library function, and a flake-parts
  flake can call it.
- **Configuration routed between entities.** den's aspects are functions of
  `{ host, user }` and route configuration across hosts, users and homes. habit
  selects per host and per user, and routes nothing between them.
