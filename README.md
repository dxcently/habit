[![Built with Nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

# habit

Host composition for NixOS: a host selects capabilities from a registry, and
only what it selected is ever imported. A crystal's habit is the shape its
conditions give it; a host's habit is the module list its selection gives it.

`mkIf` cannot keep an imported module's declarations out of the graph, and
`mkDefault` sets priority, not imports. So habit decides what a host imports
before NixOS evaluates anything, in an `evalModules` of its own, and hands
NixOS only that.

```
host record ──► selection pass ──► resolved selection ──► platform pass ──► module list ──► nixosSystem
                (gate, then select;                       (imports only           │
                 knows nothing of NixOS)                   what was kept)         └──► inventory
```

## Why habit

- **Nothing you didn't pick is imported.** An unselected capability, provider
  or group body never reaches `import`; the test suite proves it with files that
  throw the moment anything imports them.
- **Groups without lock-in.** Take a group, drop one member with
  `enable = false`, bring it back with `mkForce`. Ordinary NixOS priorities, no
  new language.
- **Every host can tell you what it is.** A generated inventory lists each
  capability, its provider and the registry path it came from; nobody keeps it
  by hand.
- **Loud, not silent.** A name two merged registries both define, a misspelt key
  in a group, a field nothing declared: each is an error naming the culprit.
- **Plain modules, one function.** A capability is an ordinary NixOS module,
  and what belongs in a user's home goes in `habit.home`; habit is a pure
  function of nixpkgs `lib`, with no other input. Call it from a flake, npins or
  a flake-parts flake.

How habit differs from den, flake-parts, snowfall-lib and blueprint:
[Comparisons](docs/comparisons.md).

## Installation

As a flake input:

```nix
inputs.habit.url = "github:dxcently/habit";
inputs.habit.inputs.nixpkgs.follows = "nixpkgs";   # habit's nixpkgs only feeds its checks
```

`habit.lib.composition` and `habit.lib.catalogues` are exported unapplied:
apply each to your own `lib`.

Without flakes, the library is `lib/composition.nix` and `lib/catalogues.nix`,
each taking `{ lib }` and nothing else, and `lib/lanes.nix`, which
`composition.nix` reads from beside itself.
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

A host selects from it and keeps its own NixOS settings, deferred:

```nix
# examples/minimal/hosts/box.nix
{
  dendrites.ssh.enable = true;

  nixos = {
    networking.hostName = "box";
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.isContainer = true;
    system.stateVersion = "26.11";
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
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

That directory is [`examples/minimal`](examples/minimal); the test suite
evaluates it, down to `config.services.openssh.enable`. Groups, providers,
users and merged registries are in [`examples/`](examples).

## Documentation

The book: <https://dxcently.github.io/habit/> (the same pages are in
[`docs/`](docs/README.md)).

| page | covers |
|---|---|
| [habit](docs/README.md) | the words, the ideas, the examples, the tests |
| [The two passes](docs/two-passes.md) | why selection runs first; gate and select; what is read when |
| [Dendrites](docs/dendrites.md) | plain modules, `habit.home`, `habit.selected`, several providers |
| [Aggregations](docs/aggregations.md) | groups, membership by priority, provider choices |
| [The host record](docs/host-record.md) | every field, users and Home Manager |
| [Override records](docs/overrides.md) | fixes that belong to a capability |
| [The constructor](docs/constructor.md) | every argument, the module list, hooks, the inventory |
| [Merging registries](docs/merging.md) | `mergeRegistries` and its errors |
| [Errors](docs/errors.md) | each error, its cause, its fix |
| [Comparisons](docs/comparisons.md) | what only habit does; when den, flake-parts, snowfall-lib or blueprint fits better |
