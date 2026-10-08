# The constructor

`lib.composition` is `lib/composition.nix`, a function of `{ lib }`. Applied,
it returns:

| name              | does                                                                       |
| ----------------- | -------------------------------------------------------------------------- |
| `mkNixosHost`     | `mkNixosModules` handed to `nixpkgs.lib.nixosSystem`                       |
| `mkDarwinHost`    | `mkModules` for `darwin` handed to `darwin.lib.darwinSystem`               |
| `mkHome`          | `mkModules` for `home` handed to `home-manager.lib.homeManagerConfiguration` |
| `mkModules`       | the platform pass for the `class` it is given: module list, `specialArgs`, selection, inventory |
| `mkNixosModules`  | `mkModules` with its `class` set to `nixos`                                |
| `evalSelection`   | `{ registry, host, specialArgs, selectionModules, scope }` -> resolved selection (gate, then select) |
| `inventoryOf`     | `{ hostName, selection }` -> what the host resolved; the review surface    |
| `implOf`, `overridesFor`, `mkSchema` | the pieces, for callers that assemble differently |

habit reads no input, so a builder takes the evaluator's own flake from the
caller and calls the evaluator on the module list. One core assembles that list
for every class; a class changes only what the next section says.

## Classes

| | `nixos` | `darwin` | `home` |
| --- | --- | --- | --- |
| builder | `mkNixosHost` | `mkDarwinHost` | `mkHome` |
| the caller supplies | `nixpkgs` | `darwin` (nix-darwin) | `home-manager`, `pkgs` |
| evaluator called | `nixpkgs.lib.nixosSystem` | `darwin.lib.darwinSystem` | `home-manager.lib.homeManagerConfiguration` |
| result | `{ system, selection, inventory }` | `{ system, selection, inventory }` | `{ home, selection, inventory }` |
| the host module is | a NixOS module | a nix-darwin module | a Home Manager module |
| scope | `system` | `system` | `home` |
| system half | applied iff some selection has `system = true` | the same | dropped, its `imports` with it; `system` changes nothing |
| home half | a `home-manager.users.<user>` definition for each user it reaches | the same | imported into the configuration itself |
| `homeManagerModule` | Home Manager's NixOS module | Home Manager's nix-darwin module | refused: the evaluator is Home Manager |
| `habit.users` | accepted | accepted | refused: a home has no users |
| `habit.aggregation.<group>` selects | the group's `system` half | the group's `system` half | the group's `home` half |
| `habit.selected` holds | the host's selection, and each user's in their home | the same | the home's selection |
| an override record applies | `overlay`, `system` (when a selection of its target has `system = true`), and `home` to the users it reaches | the same | `overlay` and `home`; its `system` is dropped with the system half |

A darwin host differs from a NixOS one in the module system it is evaluated
by and nothing else: habit declares nothing that says a module supports
darwin. A module written for NixOS only fails there as the module system's own
error, naming the module's file ([Dendrites](dendrites.md#darwin)).

## The registry

A registry is plain data, read before any module graph exists. Names and paths
only; nothing is imported at registry time.

| field          | maps             | to                                            |
| -------------- | ---------------- | --------------------------------------------- |
| `catalogue`    | capability name  | the file or directory that answers it ([Dendrites](dendrites.md)) |
| `aggregations` | group name       | a directory holding the group's `default.nix` body ([Aggregations](aggregations.md)) |
| `overrides`    | record name      | a file holding a capability-scoped fix ([Override records](overrides.md)); optional |

```nix
# examples/workstation/registry.nix
{
  catalogue = {
    bluetooth = ./dendrites/bluetooth;
    notifications = ./dendrites/notifications;
    printing = ./dendrites/printing;
  };
  aggregations = {
    desktop = ./aggregations/desktop;
  };
}
```

## Arguments

`mkModules` takes the arguments below, and `class` besides: `nixos`, `darwin`
or `home`, anything else being refused. `mkNixosModules` takes them without
`class`.

| argument            | required | default            | means                                                       |
| ------------------- | -------- | ------------------ | ----------------------------------------------------------- |
| `hostName`          | yes      |                    | the host's name, or the home's; passed on as `host`         |
| `registry`          | yes      |                    | the registry above, or the result of `mergeRegistries`      |
| `host`              | yes      |                    | the host module: a path or a module value ([The host module](host.md)) |
| `homeManagerModule` | no       | `null`             | Home Manager's module for the system (`nixosModules` or `darwinModules`); imported only if a user enables it, and needed then; refused for a home |
| `knownHosts`        | no       | `[ hostName ]`     | host names an override record's `hosts` may name            |
| `specialArgs`       | no       | `{ }`              | extra arguments for every platform and home module          |
| `overlays`          | no       | `[ ]`              | the caller's package overlays                               |
| `extraModules`      | no       | `[ ]`              | extra platform modules                                      |
| `selectionModules`  | no       | `[ ]`              | modules of `habit`: they join the scan in both steps and the platform evaluation |
| `extraModulesFor`   | no       | `_: [ ]`           | resolved selection -> platform modules                      |
| `system`            | no       | `"x86_64-linux"`   | passed on as the `system` argument only                     |

`mkNixosHost` takes the same plus `nixpkgs`, whose `lib.nixosSystem` it calls,
and returns `{ system, selection, inventory }`, where `system` is the
`nixosSystem` result. `mkDarwinHost` takes `darwin` and calls
`darwin.lib.darwinSystem` the same way. `mkHome` takes `home-manager` and
`pkgs`, calls `home-manager.lib.homeManagerConfiguration { pkgs; modules;
extraSpecialArgs; }` with the module list and `specialArgs`, and returns `{
home, selection, inventory }`. `pkgs` is the one thing habit passes on without
reading: a home's package set is the caller's.

`mkModules` and `mkNixosModules` return `{ modules, specialArgs, selection,
inventory }`; a builder adds nothing to that list, so a caller that wants the
modules for something other than the evaluator (a test node, say) takes them
from there.

The arguments that need more than a line:

- **`knownHosts`**: a record confined to a host not in it fails as "confined to
  unknown host(s)", so a consumer building several hosts passes every host name
  to each.
- **`host`** goes to the platform evaluation whole, as its last module, and to
  the scan, which reads its `habit.*` keys only. The scan applies a host that is a
  function to `specialArgs` (below), `lib` and four arguments that throw; an
  argument the host takes that none of those provides throws where it is read,
  naming the host file and the argument ([The host module](host.md#the-scan)).
  The module system's own arguments are not there: a host that reads
  `modulesPath` in a `habit` key needs it in `specialArgs`.
- **`specialArgs`** is extended with `system` and `host = hostName` (those two
  win), and the result is what every platform module, every home module and the
  scan's application of the host receives (a home's is its
  `extraSpecialArgs`). The `host` argument a module
  receives is the name; the constructor's `host` argument is the module.
- **`system`** is only that argument. The constructor never sets
  `nixpkgs.hostPlatform`: the host module itself, a selected group's
  `system.module` or an `extraModules` entry sets it, or the host fails to
  evaluate. The examples set it in the host module.
- **`homeManagerModule`** is Home Manager's `nixosModules.home-manager` for
  `nixos` and its `darwinModules.home-manager` for `darwin`. A user with
  `home.enable = true` and none given is an error naming the host, and a `home`
  that is given one is an error too: Home Manager is its evaluator, and there is
  nothing to import.
- **`overlays`**: a selected module's overlay is applied before the caller's,
  so inside it `prev` carries none of the caller's packages and reading one
  aborts with a missing attribute. A module therefore builds what it replaces
  with a fresh `callPackage`, naming every argument it needs. A caller's overlay
  that replaces a name a selected module also replaces must step aside for a
  name `prev` already carries, or it overrides the module's value. A matched
  override record's overlay is applied after the modules' and before the
  caller's.
- **`extraModules`** land after the selected modules and before the matched
  records' `system` modules, the selected groups' `system.module`s and the host
  module. A catalogue file listed
  here that the host also selected is two copies of one module, which nixpkgs
  refuses as `already declared`: select it or import it, not both
  ([Dendrites](dendrites.md#what-is-not-a-module)).

## The module list

The platform pass assembles one list, in this order:

```
 1  { nixpkgs.overlays = overlays; }               if overlays != [ ]
 2  { nixpkgs.overlays = <matched records' overlays>; }   if any
 3  habit                                          the host's `habit.*` keys, inert; `habit.selected` for the scope; the assertion
 4  each user's module, wrapped                    the accounts, and each user's `habit.home`
 5  each selected capability, wrapped              catalogue (name) order, one per capability
 6  Home Manager wiring                            if any user has home.enable
 7  extraModules ++ extraModulesFor selection
 8  each matched override record's `system`
 9  each selected group's `system.module`          group name order, one entry per module
10  host                                           the host module itself
```

A home has no users, so items 4 and 6 are empty, and the module list is the
configuration the evaluator is handed: item 5 imports each capability's home
half, item 8 is each matched record's `home` module, and item 9 each selected
group's `home.module`. The home half of a capability is an import of its
wrapped module, so a list-typed option reads it before the list's other
entries (`standaloneHomeModulesKeepTheirPosition`).

Position is not priority. A scalar defined twice at the same priority
conflicts wherever the two sit; `mkDefault`, `mkForce` and plain definitions
decide. Position shows in list-typed options, whose definitions merge in
reverse list order: the suite pins `nixpkgs.overlays` as the selected modules',
then the matched records', then the caller's (`overlayOrder`), and an
`extraModulesFor` module after a selected module and before a matched record's
`system` module (`extraModulesForKeepsItsPosition`), and a group's `system.module`
between a matched record's and the host's (`aggregationModuleSitsJustBeforeTheHost`). Overlays apply in that
order and the last to set an attribute wins, so a record's overlay beats a
selected module's, and the caller's beats the record's. The host's own overlays come
first and lose to all of them; a host that must win orders its definition
later, `nixpkgs.overlays = lib.mkAfter [ … ]`.

A home half is not in this list: it is a `home-manager.users.<user>`
definition made by the wrapped module in item 4 or 5, merged by that module's
position, so it comes before the wiring's own per-user imports
([The host module](host.md#what-a-users-home-is-made-of)).

The minimal example's list is three entries: `habit`, the wrapped `ssh`
module, the host module.

## The two hooks

Two hooks keep the constructor free of any consumer's vocabulary as a host
grows keys it has never heard of. Both default to nothing, and at their
defaults the module list is exactly the one assembled without them.

- **`selectionModules`**: modules of `habit` itself. They join the scan in both
  steps and the platform evaluation, so an option one declares is `habit.<option>`:
  a key the host can set and the gate step can read, and one the platform
  evaluation holds too. They receive `lib` and `scope` (`"system"`, or `"home"`
  for a home) as module arguments, and no `pkgs` or platform `config`. `dendrites`, `aggregation`,
  `users`, `selected` and `home` are habit's own names under `habit`: a module
  declaring one is refused, naming its file.
- **`extraModulesFor`**: a function of the resolved selection returning
  platform modules, which is how a gate-pass choice becomes an import without a
  gate-pass body import. Its modules sit with `extraModules`. It is handed the
  whole selection (`habit` as the host wrote it and resolved, so
  `selection.dendrites` and a hook's `selection.<option>`, with `catalogue`
  beside them), so it can `import` a body nothing selected; passing selected
  paths only is the caller's discipline, and the suite pins that it is possible
  (`extraModulesForCanReachTheCatalogue`).

```nix
# a key the constructor does not know, and the import it decides
selectionModules = [
  { options.role = lib.mkOption { type = lib.types.enum [ "server" "laptop" ]; }; }
];
extraModulesFor = selection: lib.optional (selection.role == "laptop") ./laptop.nix;
```

The host then writes `habit.role = "laptop";`.

## The inventory

`inventoryOf`, also `mkModules`'s and every builder's `inventory`, is what
a host resolved, derived from its selection and never maintained by hand. For
the workstation example (paths shortened to the repository root):

```json
{
  "host": "desk",
  "aggregation": [ "desktop" ],
  "dendrites": {
    "bluetooth": { "provider": null, "system": true, "source": "./examples/workstation/dendrites/bluetooth" }
  },
  "users": {
    "alice": {
      "definition": "./examples/workstation/users/alice.nix",
      "home": true,
      "aggregation": [ "desktop" ],
      "dendrites": {
        "notifications": { "provider": "dunst", "system": true, "source": "./examples/workstation/dendrites/notifications" }
      }
    }
  },
  "overrides": []
}
```

| field         | holds                                                                   |
| ------------- | ----------------------------------------------------------------------- |
| `host`        | `hostName`                                                              |
| `aggregation` | the groups the host selected                                            |
| `dendrites`   | each capability selected for the system: its `provider`, its `system` (whether the selection asks for the system half) and `source`, the catalogue path that answered |
| `users`       | per user: `definition`, `home` (whether Home Manager is on), its groups and its capabilities; `{ }` for a home |
| `overrides`   | the override records that matched this host (`mkModules` and the builders only; `inventoryOf` alone has no records to match) |

`printing` is absent: the host switched it off, so it is not part of what the
host is. The inventory says what each selection asked of a module's halves, `system`,
and nothing of the halves themselves: whether a module has a home half is known
only by importing it, which the inventory never does.

## Wiring a consumer

Each example's `default.nix` is the call a consumer makes:

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

From a flake, with that file copied to `./box`:

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

`habit.lib.composition` is unapplied; the consumer applies it with the `lib`
its own host evaluation uses, so selection runs on the consumer's lib.

### A darwin host

`mkDarwinHost` is `mkNixosHost` with nix-darwin's evaluator and Home Manager's
darwin module; the host module is a nix-darwin module. `system` defaults to
`"x86_64-linux"` and becomes the `system` module argument, so a darwin host
passes its own:

```nix
darwinConfigurations.mac =
  (composition.mkDarwinHost {
    darwin = inputs.nix-darwin;
    hostName = "mac";
    system = "aarch64-darwin";
    registry = import ./registry.nix;
    host = ./hosts/mac.nix;
    homeManagerModule = inputs.home-manager.darwinModules.home-manager;
  }).system;
```

### A standalone home

`mkHome` builds a Home Manager configuration with no system around it. The
host module is the home's own module, so it sets `home.username`,
`home.homeDirectory` and `home.stateVersion` beside its `habit.*` keys
([The host module](host.md#a-standalone-home)):

```nix
# examples/home/default.nix — a standalone Home Manager configuration.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  composition = habit.lib.composition { inherit (nixpkgs) lib; };
in
composition.mkHome {
  inherit home-manager;
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  hostName = "alice";
  registry = import ./registry.nix;
  host = ./hosts/alice.nix;
}
```

```nix
homeConfigurations.alice = (import ./home { inherit habit nixpkgs home-manager; }).home;
```
