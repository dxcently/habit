# Overview

habit is host composition for NixOS. A host selects capabilities from a
registry, and only what it selected is ever imported. A crystal's habit is the
shape its conditions give it; a host's habit is the module list its selection
gives it.

## The words

| word            | is                                                                     | page                                  |
| --------------- | ---------------------------------------------------------------------- | ------------------------------------- |
| registry        | plain data: capability, group and fix names mapped to paths            | [The constructor](constructor.md)     |
| dendrite        | a capability: one plain module, or a set of providers that are plain modules | [Dendrites](dendrites.md)        |
| half            | the system half or the home half (`habit.home`) of one module, derived when a selected module is imported | [Dendrites](dendrites.md#a-plain-module) |
| `habit.selected` | what a scope selected: a read-only option in every evaluation         | [Dendrites](dendrites.md#reading-the-selection) |
| aggregation     | a group of dendrites, written as data, selected by name                | [Aggregations](aggregations.md)       |
| host record     | what one host selects, plus its own deferred `nixos` settings          | [The host record](host-record.md)     |
| override record | a fix that belongs to a capability and applies where it was selected   | [Override records](overrides.md)      |
| nucleus         | by convention, the aggregation of dendrites every host selects         | [Aggregations](aggregations.md#what-every-host-carries) |
| inventory       | what a host resolved, derived from its selection                       | [The constructor](constructor.md#the-inventory) |

```
registry ─┐
          ├─► selection pass ─► resolved selection ─┬─► platform pass ─► module list ─► nixosSystem
host ─────┘   (gate, select)                        └─► inventory
```

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
`dendrites.printing.enable = false`, and anything above that (`mkForce true`)
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

**A pure function of `lib`.** `lib/composition.nix` and `lib/catalogues.nix`
each take `{ lib }` and nothing else: no flake inputs, no `pkgs`, no
environment (`lib/lanes.nix`, which the first reads, is the same). The flake
exports the two unapplied, so selection runs on the consumer's own `lib`, and
the library works without flakes at all.

**Names are unique across merged catalogues.** Two registries merged with `//`
let one side silently win every name both define. `mergeRegistries` refuses,
naming the name and every source defining it.
[Merging registries](merging.md)

**The inventory is derived, never hand-kept.** What a host resolved (its
groups, each capability with its provider and the path that answered, its
users, the fixes that matched) is computed from the selection itself.
[The constructor](constructor.md#the-inventory)

**The constructor knows no vocabulary.** A new field on the host record comes
in through a hook (`selectionModules`, `extraModulesFor`), not by teaching the
constructor a word. [The constructor](constructor.md#the-two-hooks)

**Every error names what failed.** The test suite greps the real message, so a
vague error is a failing test. [Errors](errors.md)

## Pages

| page                                | covers                                                          |
| ----------------------------------- | --------------------------------------------------------------- |
| [The two passes](two-passes.md)     | why selection runs first, gate and select, the boundary         |
| [Dendrites](dendrites.md)           | plain modules, `habit.home`, `habit.selected`, multi-provider capabilities |
| [Aggregations](aggregations.md)     | group bodies, membership by priority, provider choices           |
| [The host record](host-record.md)   | every field a host sets, users and Home Manager                  |
| [Override records](overrides.md)    | capability-scoped fixes, matching, the weaker boundary           |
| [The constructor](constructor.md)   | every argument, the module list order, hooks, the inventory      |
| [Merging registries](merging.md)    | `mergeRegistries`, the source shape, its errors                  |
| [Errors](errors.md)                 | each error habit throws, its cause, its fix                      |
| [Comparisons](comparisons.md)       | what only habit does, and when den, flake-parts, snowfall-lib or blueprint fits better |

## Examples

Three directories under
[`examples/`](https://github.com/dxcently/habit/tree/main/examples), each a
registry, its dendrites, a host and the call that builds it. The test suite
calls each one the way a flake would and checks its inventory, its module list
and real NixOS option values. Every example file quoted in these pages is the
file the suite evaluates.

| example                                                                           | shows                                                        |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [`minimal`](https://github.com/dxcently/habit/tree/main/examples/minimal)         | one dendrite, one host                                       |
| [`workstation`](https://github.com/dxcently/habit/tree/main/examples/workstation) | an aggregation, a member switched off, a provider choice, a Home Manager user |
| [`merged`](https://github.com/dxcently/habit/tree/main/examples/merged)           | two registries merged, a group in one naming a capability in the other |

## Tests

`tests/selection/` holds executable cases over a fixture registry
(`registry.nix`, `dendrites/`, `aggregations/`, `overrides/`, `users/`,
`badrecords/`), over the wrapper (`lanes/`) and over the examples. A fixture
implementation or aggregation body that throws on import proves that "never
imported" is a fact, not a claim. `run.sh` evaluates each case on its own; a
negative case must throw AND carry its expected message.

```
./tests/selection/run.sh [case]     # needs nix and jq
nix flake check                     # the same suite, sandboxed, and this book
```

`checks.x86_64-linux.docs` builds this book with mdBook after
`tests/docs/quotes.sh` confirms that every quoted example file matches the file
on disk.
