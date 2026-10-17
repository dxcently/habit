[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org) [![Nix flakes](https://img.shields.io/badge/Nix-flakes-5277C3?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)

# habit

Host composition for NixOS, nix-darwin and standalone Home Manager: a host
selects capabilities from a registry, and only what it selected is ever
imported. A crystal's habit is the shape its
conditions give it; a host's habit is the module list its selection gives it.

`mkIf` cannot keep an imported module's declarations out of the graph, and
`mkDefault` sets priority, not imports. So habit decides what a host imports
before NixOS evaluates anything, in an `evalModules` of its own, and hands
NixOS only that. The pipeline is under [How it works](#how-it-works).

## Why habit

- **Nothing you didn't pick is imported.** An unselected capability, provider
  or group body never reaches `import`, and an unselected module value is never
  applied; the test suite proves it with files and values that throw the moment
  anything reads them.
- **Groups without lock-in.** Take a group, drop one member with
  `enable = false`, bring it back with `mkForce`. Ordinary NixOS priorities, no
  new language.
- **Every host can tell you what it is.** A generated inventory lists each
  capability, its provider and the registry entry it came from; nobody keeps it
  by hand.
- **Loud, not silent.** A name two merged registries both define, a misspelt key
  in a group, a field nothing declared: each is an error naming the culprit.
- **The host is one module.** NixOS evaluates it whole; habit reads only its
  `habit.*` keys, and refuses a selection that depends on the configuration it
  is choosing.
- **Plain modules, one function.** A capability is an ordinary NixOS module,
  and what belongs in a user's home goes in `habit.home`; habit is a pure
  function of nixpkgs `lib`, with no other input. Call it from a flake, npins or
  a flake-parts flake.
- **One module, three targets.** The same capability serves a NixOS host, a
  nix-darwin host and a standalone Home Manager configuration: the builder
  (`mkNixosHost`, `mkDarwinHost`, `mkHome`) takes the evaluator from you, and a
  home drops the module's system half and keeps its home half. A selection can
  ask for the home half alone with `system = false`.

How habit differs from den, flake-parts, snowfall-lib and blueprint:
[Comparisons](docs/comparisons.md).

## How it works

The registry names what exists and the host module says what is wanted.
Selection keeps what the host asks for, before NixOS evaluates anything.

### The registry

```
registry
├── catalogue      name ─► entry     one per capability (a dendrite)
│     entry = path       a module, or a provider set, in a file
│           | value      a module as an attrset or a function
│           | { providers = { <p> = path | value; }; }
├── aggregations   name ─► path      a directory whose default.nix is the body
│     body = { description?; system? = { members?; providers?; module?; };
│                            home?   = { members?; providers?; module?; }; }
└── overrides      name ─► path      a record file, optional
      record = { dendrites; hosts?; overlay?; system?; home?; }
```

Every field marked `?` is optional. A record needs `dendrites` and at least one
of `overlay`, `system` or `home`.

[Dendrites](docs/dendrites.md), [Aggregations](docs/aggregations.md),
[Override records](docs/overrides.md). `mergeRegistries` merges the three
fields by name; a name two sources define is an error
([Merging registries](docs/merging.md)).

### The host's keys

[The host module](docs/host.md#keys). Each account's own keys are under
[users](docs/host.md#users).

```
host module
├── habit.dendrites.<name>        <name> from catalogue
│   ├── enable    bool            false
│   ├── provider  null | string   for a provider set
│   └── system    bool            true; false selects the home half alone
├── habit.aggregation.<group>     <group> from aggregations
│   ├── enable    bool            false; a host selects the system half, a home the home half
│   └── <member>.provider         provider-bearing members only
├── habit.users.<user>            per-user selection
│   ├── definition   path
│   ├── home.enable  bool         false
│   ├── home.config  deferred module
│   ├── dendrites.<name>.{enable,provider,system}
│   └── aggregation.<group>.{enable,<member>.provider}
├── habit.catalogue               read-only; the registry's catalogue
└── everything else               the host's own config; selection never reads it
```

### What is read when

[The evaluation boundary](docs/two-passes.md#the-evaluation-boundary)

| read | when |
| --- | --- |
| registry names and paths | always |
| each catalogue entry, to its kind | always; a `throw` entry fails here, selected or not |
| override record files | always, on every host; only a matched record's functions are called |
| a selected entry: its file or value | iff a scope enabled it |
| a provider set's `providers` | iff its capability is enabled |
| the chosen provider's target | iff it is the one chosen; the other targets are never read |
| an aggregation body | iff the host or one of its users selected the group |
| a user's definition | for every user on the host |
| anything unselected: an entry's attributes or function body, a provider, a body | never |

### The pipeline

[The two passes](docs/two-passes.md), [the module list](docs/constructor.md#the-module-list)

```
host module ──┐
              ├──► selection pass ─────────── reads only literal habit.* keys
registry ─────┘     gate:   which groups are selected
                    select: their bodies, members and providers
                       │
                       ▼
                 resolved selection ─────────► inventory (inventoryOf)
                       │
                       ▼
                 platform pass ──────────────── imports and applies only what was kept
                       │
                       ▼
                 module list ────────────────── habit, users, dendrites, Home Manager
                       │                        wiring, extraModules, records, groups, host
                       ▼
                 builder ────────────────────── mkNixosHost | mkDarwinHost | mkHome
                       │                        (the evaluator is yours)
                       ▼
                 system | home
```

### One rule worth knowing

- **One provider per capability per system.** The host, its groups and its users
  must agree. A host or user clash is an error naming every claimant; two groups
  choosing different providers give the module system's "conflicting definition
  values" error ([Dendrites](docs/dendrites.md#several-providers),
  [Aggregations](docs/aggregations.md)).

## Installation

As a flake input:

```nix
inputs.habit.url = "github:dxcently/habit";
inputs.habit.inputs.nixpkgs.follows = "nixpkgs";   # habit's nixpkgs only feeds its checks
```

`habit.lib.composition` and `habit.lib.catalogues` are exported unapplied:
apply each to your own `lib`.

Without flakes, the library is `lib/composition.nix` and `lib/catalogues.nix`,
each taking `{ lib }` and nothing else, and `lib/lanes.nix` and `lib/scan.nix`,
which `composition.nix` reads from beside itself.
With [npins](https://github.com/andir/npins) (or `fetchTarball`) providing
`nixpkgs`, `habit` and `home-manager`, a NixOS host's module list is
`mkNixosModules`'s (`mkModules` takes the `class` of a darwin host or a home):

```nix
let
  sources = import ./npins;
  lib = import "${sources.nixpkgs}/lib";
  composition = import "${sources.habit}/lib/composition.nix" { inherit lib; };

  box = composition.mkNixosModules {
    hostName = "box";
    registry = import ./registry.nix;
    host = ./hosts/box.nix;
    homeManagerModule = "${sources.home-manager}/nixos";
  };
in
import "${sources.nixpkgs}/nixos/lib/eval-config.nix" {
  system = null;
  inherit (box) modules specialArgs;
}
```

## Quick start

A capability (a "dendrite") is a plain NixOS module:

```nix
# examples/minimal/dendrites/ssh.nix
{
  services.openssh.enable = true;
}
```

A registry names capabilities and groups; nothing in it is imported until a
host selects it:

```nix
# examples/minimal/registry.nix
{
  catalogue = {
    ssh = ./dendrites/ssh.nix;
  };
  aggregations = { };
}
```

A host is one module. Its `habit.*` keys select from the registry; everything
else in it is the host's own NixOS configuration:

```nix
# examples/minimal/hosts/box.nix
{
  habit.dendrites.ssh.enable = true;

  networking.hostName = "box";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

The constructor turns that into a NixOS system:

```nix
# examples/minimal/default.nix — one capability, one host.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  composition = habit.lib.composition { inherit (nixpkgs) lib; };
in
composition.mkNixosHost {
  inherit nixpkgs;
  hostName = "box";
  registry = import ./registry.nix;
  host = ./hosts/box.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

That directory is [`examples/minimal`](examples/minimal); the test suite
evaluates it, down to `config.services.openssh.enable`. Groups, providers,
users and merged registries are in [`examples/`](examples).

The same registry builds for nix-darwin with `mkDarwinHost` and as a standalone
Home Manager configuration with `mkHome`, each taking its evaluator from you ([The constructor](docs/constructor.md#classes),
[`examples/home`](examples/home)).

## Targets and how they are checked

| target | builder | evaluated by the checks |
|---|---|---|
| NixOS, with Home Manager's NixOS module | `mkNixosHost` | the real `nixosSystem`, down to `system.build.toplevel.drvPath` |
| nix-darwin, with Home Manager's darwin module | `mkDarwinHost` | the real `darwinSystem` for `aarch64-darwin`, from Linux, down to `system.build.toplevel.drvPath` |
| standalone Home Manager | `mkHome` | the real `homeManagerConfiguration`, down to `home.activationPackage.drvPath` |

```
./tests/selection/run.sh      # the selection cases; stubs stand in for nix-darwin and Home Manager
nix flake check ./tests       # the real NixOS, Home Manager and nix-darwin; fetches them
nix flake check               # the selection suite, sandboxed, and the book
```

`tests/flake.nix` has its own lock: Home Manager and nix-darwin are inputs of
that flake alone, so this repository's root lock holds nixpkgs and a consumer's
lock gains neither. The checks evaluate; nothing is built on a Mac
([Tests](docs/README.md#tests)).

## Documentation

The book: <https://dxcently.github.io/habit/> (the same pages are in
[`docs/`](docs/README.md)).

| page | covers |
|---|---|
| [habit](docs/README.md) | the words, the ideas, the examples, the tests |
| [The two passes](docs/two-passes.md) | why selection runs first; gate and select; what is read when |
| [Dendrites](docs/dendrites.md) | plain modules, `habit.home`, `habit.selected`, several providers |
| [Aggregations](docs/aggregations.md) | groups, membership by priority, provider choices |
| [The host module](docs/host.md) | the `habit.*` keys, the scan and its limits, users and Home Manager, darwin and standalone homes |
| [Override records](docs/overrides.md) | fixes that belong to a capability |
| [The constructor](docs/constructor.md) | the classes and their builders, every argument, the module list, hooks, the inventory |
| [Merging registries](docs/merging.md) | `mergeRegistries` and its errors |
| [Errors](docs/errors.md) | each error, its cause, its fix |
| [Comparisons](docs/comparisons.md) | what only habit does; when den, flake-parts, snowfall-lib or blueprint fits better |
