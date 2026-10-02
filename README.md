# habit

Host composition for NixOS: a host selects capabilities from a registry, and
only what it selected is ever imported. A crystal's habit is the shape its
conditions give it; a host's habit is the module list its selection gives it.

habit is a pure function of `lib`. It reads no flake input at runtime, and its
one `nixpkgs` input exists only for `checks`.

## Two passes

```
host record ──► selection pass ──► resolved selection ──► platform pass ──► module list
                (evalModules,                              (imports only
                 knows nothing                              what selection
                 of NixOS)                                  kept)
```

`mkDefault` sets definition priority; it cannot decide imports, and `mkIf` cannot
keep an imported module's declarations out of the graph that imported them. So
selection is resolved first, by an ordinary `lib.evalModules` over a small
schema, and the platform import list is assembled from the result.

**Selection** runs in two steps, because a host nests provider choices under the
aggregation that owns them and those option names come from the aggregation's own
body:

- gate: every aggregation declares only `enable`; the answer is which
  aggregations the host, or one of its users, selects.
- select: the selected bodies are imported, declare their real options, and write
  their membership. Nothing else is read.

**Platform** takes the resolved selection and imports, per scope, the lane each
selected capability exposes. An unselected catalogue entry is never `import`ed;
an unselected provider file is never read.

The `nixos` part of a host record is a `deferredModule`: nothing in it can
influence selection, which is what keeps the two passes from chasing each other.

## The registry

A registry is plain data, read before any module graph exists.

```nix
{
  catalogue     = { notifications = ./caps/notifications; obsidian = ./caps/obsidian.nix; };
  aggregations  = { workstation = ./groups/workstation; };
  overrides     = { broken-upstream = ./fixes/broken-upstream.nix; };   # optional
}
```

| field          | maps                  | to                                                         |
| -------------- | --------------------- | ---------------------------------------------------------- |
| `catalogue`    | capability name       | the file or directory that answers it                      |
| `aggregations` | group name            | a directory holding the group's `default.nix` body         |
| `overrides`    | record name           | a file holding a capability-scoped fix                     |

Names and paths only. Nothing is imported at registry time.

**A capability** (a "dendrite") is a lane record: `{ nixos = …; homeManager = …; }`,
each lane a module for one evaluator, only the lanes it supports. A multi-provider
capability is `{ providers = { a = ./a.nix; b = ./b.nix; }; }` where each provider
file is a lane record. Selecting a lane a capability does not expose is an error
naming the lanes it does.

**An aggregation** is data: `description`, then per scope (`system`, `home`) its
`members` (capability names), `providers` (default provider per provider-bearing
member), and optionally `nixos` / `homeManager` settings that ride the platform
pass. Membership is `mkDefault`, so an ordinary selection outranks it, two
aggregations naming one member merge, and two choosing different providers for it
collide rather than letting import order pick a winner. An aggregation cannot
select another aggregation.

**An override record** is a fix that belongs to a capability, not a host:
`{ dendrites = [ … ]; hosts = [ … ] (optional); overlay; nixos; homeManager; }`.
It applies to the hosts that selected one of its targets (and its `homeManager`
module only to the users that did). It selects nothing. Unknown fields, no
targets, unknown targets, unknown hosts, and a record carrying nothing are errors
naming the record and its file. The evaluation boundary is weaker than
selection's: every host imports every record file to match it; only the record's
functions stay uncalled when it does not match.

## The host record

```nix
{
  aggregation.workstation.enable = true;            # groups
  aggregation.workstation.notifications.provider = "dunst";
  dendrites.obsidian.enable = true;                 # lone capabilities
  users.khoa = {
    definition = ./users/khoa.nix;                  # { nixos; homeManager? }
    homeManager.enable = true;
    dendrites.notifications = { enable = true; provider = "mako"; };
    homeManager.config = { … };                     # extra home settings
  };
  nixos = { pkgs, ... }: { … };                     # this machine, deferred
}
```

A group's member is turned off the ordinary way:
`dendrites.kitty.enable = false` outranks the group's `mkDefault`. A user who
selects home capabilities with `homeManager.enable = false` is an error, not a
quiet no-op.

## The constructor

`lib.composition` is the file `lib/composition.nix`, a function of `{ lib }`.

| name                | does                                                                    |
| ------------------- | ----------------------------------------------------------------------- |
| `evalSelection`     | `{ registry, modules }` -> resolved selection (gate, then select)       |
| `inventoryOf`       | `{ hostName, selection }` -> what the host resolved; the review surface |
| `mkNixosModules`    | the platform pass: module list, `specialArgs`, selection, inventory     |
| `mkNixosHost`       | `mkNixosModules` handed to `nixpkgs.lib.nixosSystem`                    |
| `lanesFor`, `implOf`, `overridesFor`, `mkSchema`, `laneNames` | the pieces, for callers that assemble differently |

`mkNixosModules` takes `hostName`, `registry`, `hostModules`, `nucleus` (the
unconditional core module), `homeManagerModule`, and optionally `knownHosts`,
`specialArgs`, `extraModules`, `overlays`, `system`, and two hooks that keep the
constructor free of any vocabulary. Four of those arguments need a word:

- `knownHosts` (default `[ hostName ]`) is the set of host names an override
  record's `hosts = [ … ]` may name. A record confined to a host not in it fails
  as "confined to unknown host(s)", so a consumer building several hosts passes
  every host name to each.
- `specialArgs` is extended with `system` and `host = hostName` (those two win),
  and the result is what every platform module and every home module receives.
  `system` is only that argument: the constructor never sets
  `nixpkgs.hostPlatform`, so the `nucleus` or the host's own `nixos` module sets
  it, or the host fails to evaluate.
- `overlays` are the caller's package overlays. A lane's overlay runs before
  them, so a lane's `prev` carries none of the caller's packages.
- `extraModules` land after the lanes and before override modules and the host's
  own `nixos`. An `extraModules` path, or one returned by `extraModulesFor`, that
  is the directory holding catalogue entries (an aggregate importing every
  capability's body), together with any selected capability, is refused by name,
  because both import the same body and the options would be declared twice.
  Take the whole directory and select nothing, or select and drop it.

A capability's lane names are `nixos`, `darwin` and `homeManager`. Only `nixos`
and `homeManager` are consumed: there is no darwin constructor, so `darwin` is
accepted as a name a capability may carry and is never imported. Override records
take no `darwin` field.

- `selectionModules`: modules that join the host's own in BOTH selection steps,
  so a field they declare is a field the host record can set and the gate step
  can read.
- `extraModulesFor`: a function of the resolved selection returning platform
  modules, which is how a gate-pass choice becomes an import without a gate-pass
  body import. It is handed the whole selection, catalogue values included, so
  passing a path nothing selected is the caller's mistake to avoid.

Both default to nothing: `[ ]` and `_: [ ]`.

The inventory (`inventoryOf`, also `mkNixosModules`'s `inventory`) lists the
aggregations, every capability selected with its provider and the file that
answered, its users, and which override records matched. It is derived from
selection, never maintained by hand.

## Merging registries: `lib.catalogues`

A consumer that merges two registries with `//` lets one side silently win every
name both define. `lib.catalogues` refuses instead.

```
mergeRegistries :: [ source ] -> { catalogue; aggregations; overrides; }

source = { name :: string; catalogue ? {}; aggregations ? {}; overrides ? {}; }
```

A name defined by more than one source throws, naming the name and each source:

```
catalogue names defined by more than one source: 'notifications' by aoide and dxflake
```

A source takes only `name`, `catalogue`, `aggregations` and `overrides`; any
other field (a misspelt `aggregation`) throws, naming the source and the field.
A source that is not an attrset (a forgotten `import`), a source without a
string `name`, two sources sharing a name, and a field that is present but not
an attrset (`catalogue = null`) each throw, naming the source or its position. A field may be absent.

The result is a registry, ready to hand to the constructor. Aggregations and
overrides follow the same rule as the catalogue: they are keyed by name exactly
as it is, a clash drops one side's group or fix without a trace, and the host
record selects them by that name. Each field is merged when it is read, so a
clash is reported by the field it is in, while a fault of a whole source (not
an attrset, an unknown field, no name) is reported by whichever field is read
first. Because a clash is an error, the result does not depend on source order.

## Wiring a consumer

```nix
{
  inputs.habit.url = "github:…/habit";
  inputs.habit.inputs.nixpkgs.follows = "nixpkgs";   # habit's nixpkgs only feeds its checks

  outputs = { nixpkgs, habit, … }:
    let
      inherit (nixpkgs) lib;
      composition = habit.lib.composition { inherit lib; };
      catalogues  = habit.lib.catalogues  { inherit lib; };
      mine = {
        name = "mine";
        catalogue = { notifications = ./caps/notifications; };
        aggregations = { workstation = ./groups/workstation; };
        overrides = { };
      };
      other = otherRegistry // { name = "other"; };   # otherRegistry carries only catalogue, aggregations, overrides
      registry = catalogues.mergeRegistries [ mine other ];
    in
    {
      nixosConfigurations.box = (composition.mkNixosHost {
        inherit nixpkgs registry;
        hostName = "box";
        hostModules = [ ./hosts/box ];
        nucleus = ./nucleus;                 # sets nixpkgs.hostPlatform
        homeManagerModule = home-manager.nixosModules.home-manager;
      }).system;
    };
}
```

The exports are unapplied: the consumer applies each with the `lib` its own host
evaluation uses, so selection runs on the consumer's lib.

## Tests

`tests/selection/` holds executable cases over a fixture registry
(`registry.nix`, `dendrites/`, `aggregations/`, `overrides/`, `users/`,
`badrecords/`). A fixture implementation or aggregation body that throws on
import proves that "never imported" is a fact, not a claim. `run.sh` evaluates
each case on its own; a negative case must throw AND carry its expected message.

```
./tests/selection/run.sh [case]     # needs nix and jq
nix flake check                     # the same suite, sandboxed
```
