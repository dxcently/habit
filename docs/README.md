# Overview

habit is host composition for NixOS, nix-darwin and standalone Home Manager. A
host selects capabilities from a registry, and only what it selected is ever
imported. A crystal's habit is the
shape its conditions give it; a host's habit is the module list its selection
gives it.

## The words

| word            | is                                                                     | page                                  |
| --------------- | ---------------------------------------------------------------------- | ------------------------------------- |
| registry        | plain data: capability, group and fix names mapped to paths            | [The constructor](constructor.md)     |
| dendrite        | a capability: one plain module, or a set of providers that are plain modules | [Dendrites](dendrites.md)        |
| half            | the system half or the home half (`habit.home`) of one module, derived when a selected module is imported | [Dendrites](dendrites.md#a-plain-module) |
| `habit.selected` | what a scope selected: a read-only option in every evaluation         | [Dendrites](dendrites.md#reading-the-selection) |
| scan            | how selection reads the host module: its `habit.*` keys only, never the platform's values | [The host module](host.md#the-scan) |
| aggregation     | a group of dendrites, written as data, selected by name                | [Aggregations](aggregations.md)       |
| host module     | one module: its `habit.*` keys select, everything else is the host's own platform configuration | [The host module](host.md) |
| class           | what a host is built for: `nixos`, `darwin` or `home`; it sets the scope and the evaluator the caller supplies | [The constructor](constructor.md#classes) |
| override record | a fix that belongs to a capability and applies where it was selected   | [Override records](overrides.md)      |
| nucleus         | by convention, the aggregation of dendrites every host selects         | [Aggregations](aggregations.md#what-every-host-carries) |
| inventory       | what a host resolved, derived from its selection                       | [The constructor](constructor.md#the-inventory) |

```
registry ─┐
          ├─► selection pass ─► resolved selection ─┬─► platform pass ─► module list ─► your evaluator
host ─────┘   (gate, select)                        └─► inventory
```

The evaluator is `nixosSystem`, `darwinSystem` or `homeManagerConfiguration`,
and the caller supplies it: habit takes no flake input.

## The ideas

**Selection happens before import.** `mkDefault` sets a definition's
priority; it cannot decide whether a module is imported. `mkIf` cannot keep an
imported module's option declarations out of the graph that imported it. So
the decision of what to import cannot live inside the NixOS evaluation it
shapes. habit resolves it first, in an `evalModules` of its own that knows
nothing of NixOS, and builds the import list from the answer.
[The two passes](two-passes.md)

**Selection is by priority.** A group's membership is written with
`mkDefault`, so a host switches one member off with a plain
`habit.dendrites.printing.enable = false`, and anything above that (`mkForce true`)
switches it back on. No second group, no exclude list, no `mkIf`: the same
priorities that settle every other NixOS option settle membership.
[Aggregations](aggregations.md)

**A dendrite is a plain module.** habit's own vocabulary on the capability side
is `habit.home` for what belongs in a user's home and `habit.selected` for what
was selected. Which half goes where is decided when a selected module is
imported, by who selected it. [Dendrites](dendrites.md)

**Nothing unselected is imported.** A catalogue entry, a provider file and an
aggregation body are each `import`ed if and only if selection kept them. The
suite proves it with fixtures that throw when imported. The one weaker
boundary, override records, is stated where it lives.
[Override records](overrides.md#the-evaluation-boundary)

**The host is one module, and selection reads part of it.** NixOS evaluates the
host module whole. Selection reads only its literal `habit.*` keys: the
platform's own arguments (`config`, `pkgs`) throw if the scan touches them, its
`imports` are not followed and every other key is never forced. A selection
that depends on the platform is refused by name; one written in an imported
file is caught by an assertion in the platform evaluation.
[The host module](host.md#the-scan)

**A pure function of `lib`.** `lib/composition.nix` and `lib/catalogues.nix`
each take `{ lib }` and nothing else: no flake inputs, no `pkgs`, no
environment (`lib/lanes.nix` and `lib/scan.nix`, which the first reads, are the
same). The flake exports the two unapplied, so selection runs on the consumer's
own `lib`, and the library works without flakes at all.

**Names are unique across merged catalogues.** Two registries merged with `//`
let one side silently win every name both define. `mergeRegistries` refuses,
naming the name and every source defining it.
[Merging registries](merging.md)

**The inventory is derived, never hand-kept.** What a host resolved (its
groups, each capability with its provider and the path that answered, its
users, the fixes that matched) is computed from the selection itself.
[The constructor](constructor.md#the-inventory)

**The constructor knows no consumer's vocabulary.** It knows habit's own words
(`habit.dendrites`, `habit.aggregation`, `habit.users`, `habit.home`,
`habit.selected`). A consumer's field comes in through a hook
(`selectionModules`, `extraModulesFor`), not by teaching the constructor a word.
[The constructor](constructor.md#the-two-hooks)

**Every error names what failed.** The test suite greps the real message, so a
vague error is a failing test. [Errors](errors.md)

## Pages

| page                                | covers                                                          |
| ----------------------------------- | --------------------------------------------------------------- |
| [The two passes](two-passes.md)     | why selection runs first, gate and select, the boundary         |
| [Dendrites](dendrites.md)           | plain modules, `habit.home`, `habit.selected`, multi-provider capabilities |
| [Aggregations](aggregations.md)     | group bodies, membership by priority, provider choices           |
| [The host module](host.md)          | the `habit.*` keys, the scan and its limits, users and Home Manager, darwin and standalone homes |
| [Override records](overrides.md)    | capability-scoped fixes, matching, the weaker boundary           |
| [The constructor](constructor.md)   | the classes and their builders, every argument, the module list order, hooks, the inventory |
| [Merging registries](merging.md)    | `mergeRegistries`, the source shape, its errors                  |
| [Errors](errors.md)                 | each error habit throws, its cause, its fix                      |
| [Comparisons](comparisons.md)       | what only habit does, and when den, flake-parts, snowfall-lib or blueprint fits better |

## Examples

Four directories under
[`examples/`](https://github.com/dxcently/habit/tree/main/examples), each a
registry, its dendrites, a host and the call that builds it. The test suite
calls each one the way a flake would and checks its inventory, its module list
and option values: real NixOS ones, and for `home` those of a stub of Home
Manager's options (the real ones are in `tests/real/`, below). Every example file
quoted in these pages is the file the suite evaluates.

| example                                                                           | shows                                                        |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [`minimal`](https://github.com/dxcently/habit/tree/main/examples/minimal)         | one dendrite, one host                                       |
| [`workstation`](https://github.com/dxcently/habit/tree/main/examples/workstation) | an aggregation, a member switched off, a provider choice, a Home Manager user |
| [`merged`](https://github.com/dxcently/habit/tree/main/examples/merged)           | two registries merged, a group in one naming a capability in the other |
| [`home`](https://github.com/dxcently/habit/tree/main/examples/home)               | a standalone Home Manager configuration; a module's system half dropped |

## Tests

`tests/selection/` holds executable cases over a fixture registry
(`registry.nix`, `dendrites/`, `aggregations/`, `overrides/`, `users/`,
`badrecords/`), over host modules (`hosts/`) and the hooks (`hooks/`), over the
wrapper (`lanes/`), over each class against stub option trees named like
nix-darwin's and Home Manager's, and over the examples. A fixture
implementation or aggregation body that throws on import proves that "never
imported" is a fact, not a claim. `run.sh` evaluates each case on its own; a
negative case must throw AND carry its expected message.

```
./tests/selection/run.sh [case]     # needs nix and jq
nix flake check                     # the same suite, sandboxed, and this book
nix flake check ./tests             # real NixOS, Home Manager and nix-darwin; fetches them
```

The selection suite has no input but nixpkgs, so a stub stands in for
nix-darwin and Home Manager there. `tests/flake.nix` has its own lock file and
pins Home Manager and nix-darwin to revisions that evaluate against the
nixpkgs the root flake pins; the root flake and its lock hold nixpkgs alone, so
a consumer's lock never gains either. Each case in `tests/real/` is a value read
from a real evaluation and the value it must equal, and the command evaluates
from `x86_64-linux`:

| target | evaluated | what the cases pin |
| ------ | --------- | ------------------ |
| NixOS with Home Manager's NixOS module (`mkNixosHost`) | `nixosSystem`, down to `system.build.toplevel.drvPath` | a host's selection reaches every user and a user's reaches that user alone; a plain home half and one under `mkOverride` both reach the user; a function-valued `habit.home` takes `lib.hm`; `habit.selected` holds each scope; the builder's arguments reach every module |
| nix-darwin with Home Manager's darwin module (`mkDarwinHost`) | `darwinSystem` for `aarch64-darwin`, down to `system.build.toplevel.drvPath` | the system half applies; the home half routes through Home Manager, whose home directory comes from the user module's `users.users.<user>.home`; a Linux-only option fails, as a file entry and as a directory entry, and the module system names the module's file in both |
| standalone Home Manager (`mkHome`) | `homeManagerConfiguration`, down to `home.activationPackage.drvPath`, and `examples/home` | the system half is dropped and the home half lands; `habit.selected` is the home's; the caller's and a record's overlays both apply; `extraSpecialArgs` reach modules |

Nothing there is built: a darwin builder is not needed to evaluate.

`checks.x86_64-linux.docs` builds this book with mdBook after
`tests/docs/quotes.sh` confirms that every quoted example file matches the file
on disk.
