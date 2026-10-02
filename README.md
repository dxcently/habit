[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

# habit

Host composition for NixOS: a host selects capabilities from a registry, and
only what it selected is ever imported. A crystal's habit is the shape its
conditions give it; a host's habit is the module list its selection gives it.

`mkIf` cannot keep an imported module's declarations out of the graph, and
`mkDefault` sets priority, not imports. So habit decides what a host imports
before NixOS evaluates anything, in an `evalModules` of its own, and hands
NixOS only that. Group membership is settled by ordinary priorities, so a host
switches one member of a group off with `enable = false`. habit is a pure
function of nixpkgs `lib`.

```
host record ──► selection pass ──► resolved selection ──► platform pass ──► module list ──► nixosSystem
                (gate, then select;                       (imports only           │
                 knows nothing of NixOS)                   what was kept)         └──► inventory
```

## Installation

As a flake input:

```nix
inputs.habit.url = "github:dxcently/habit";
inputs.habit.inputs.nixpkgs.follows = "nixpkgs";   # habit's nixpkgs only feeds its checks
```

`habit.lib.composition` and `habit.lib.catalogues` are exported unapplied:
apply each to your own `lib`.

Without flakes, the library is two files that take `{ lib }` and nothing else.
With [npins](https://github.com/andir/npins) (or `fetchTarball`) providing
`nixpkgs`, `habit` and `home-manager`:

```nix
let
  sources = import ./npins;
  lib = import "${sources.nixpkgs}/lib";
  composition = import "${sources.habit}/lib/composition.nix" { inherit lib; };

  box = composition.mkNixosModules {
    hostName = "box";
    registry = import ./registry.nix;
    hostModules = [ ./hosts/box.nix ];
    nucleus = ./nucleus.nix;
    homeManagerModule = "${sources.home-manager}/nixos";
  };
in
import "${sources.nixpkgs}/nixos/lib/eval-config.nix" {
  system = null;
  inherit (box) modules specialArgs;
}
```

## Quick start

A capability (a "dendrite") is a record of modules per evaluator:

```nix
# examples/minimal/dendrites/ssh.nix
{
  nixos = {
    services.openssh.enable = true;
  };
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

A host selects from it and keeps its own NixOS settings, deferred:

```nix
# examples/minimal/hosts/box.nix
{
  dendrites.ssh.enable = true;

  nixos = {
    networking.hostName = "box";
  };
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
  hostModules = [ ./hosts/box.nix ];
  nucleus = ./nucleus.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

That directory is [`examples/minimal`](examples/minimal); the test suite
evaluates it, down to `config.services.openssh.enable`. Groups, providers,
users and merged registries are in [`examples/`](examples).

## Compared

| | how a host drops one member of a shared group | unselected modules imported? | darwin / standalone Home Manager | discovers files |
|---|---|---|---|---|
| habit | `dendrites.<m>.enable = false`; `mkForce` puts it back | no (override records are read to be matched) | no / no | no |
| [den](https://github.com/vic/den) | `excludes`, an append-only list | excluded aspects are not applied | yes / yes | no |
| dendritic + [flake-parts](https://flake.parts) | not by priority: `imports` is a plain list | wherever a list names them | yes / yes | by convention |
| [snowfall-lib](https://github.com/snowfallorg/lib) | the module gates itself | every module, every system | yes / yes | yes |
| [blueprint](https://github.com/numtide/blueprint) | no groups | a host imports what it names | yes / yes | yes |

Sources, revisions and where each one wins: [Comparisons](docs/comparisons.md).

## Documentation

The book: <https://dxcently.github.io/habit/> (the same pages are in
[`docs/`](docs/README.md)).

| page | covers |
|---|---|
| [habit](docs/README.md) | the words, the ideas, the examples, the tests |
| [The two passes](docs/two-passes.md) | why selection runs first; gate and select; what is read when |
| [Dendrites](docs/dendrites.md) | lane records, lanes, several providers |
| [Aggregations](docs/aggregations.md) | groups, membership by priority, provider choices |
| [The host record](docs/host-record.md) | every field, users and Home Manager |
| [Override records](docs/overrides.md) | fixes that belong to a capability |
| [The constructor](docs/constructor.md) | every argument, the module list, hooks, the inventory |
| [Merging registries](docs/merging.md) | `mergeRegistries` and its errors |
| [Errors](docs/errors.md) | each error, its cause, its fix |
| [Comparisons](docs/comparisons.md) | den, dendritic + flake-parts, snowfall-lib, blueprint |
