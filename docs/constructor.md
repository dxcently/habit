# The constructor

`lib.composition` is `lib/composition.nix`, a function of `{ lib }`. Applied,
it returns:

| name              | does                                                                       |
| ----------------- | -------------------------------------------------------------------------- |
| `mkNixosHost`     | `mkNixosModules` handed to `nixpkgs.lib.nixosSystem`                       |
| `mkNixosModules`  | the platform pass: module list, `specialArgs`, selection, inventory        |
| `evalSelection`   | `{ registry, modules }` -> resolved selection (gate, then select)          |
| `inventoryOf`     | `{ hostName, selection }` -> what the host resolved; the review surface    |
| `implOf`, `overridesFor`, `mkSchema` | the pieces, for callers that assemble differently |

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

`mkNixosModules` takes:

| argument            | required | default            | means                                                       |
| ------------------- | -------- | ------------------ | ----------------------------------------------------------- |
| `hostName`          | yes      |                    | the host's name; passed on as `host`                        |
| `registry`          | yes      |                    | the registry above, or the result of `mergeRegistries`      |
| `hostModules`       | yes      |                    | the host record's modules ([The host record](host-record.md)) |
| `homeManagerModule` | yes      |                    | Home Manager's NixOS module; imported only if a user enables it |
| `knownHosts`        | no       | `[ hostName ]`     | host names an override record's `hosts` may name            |
| `specialArgs`       | no       | `{ }`              | extra arguments for every platform and home module          |
| `overlays`          | no       | `[ ]`              | the caller's package overlays                               |
| `extraModules`      | no       | `[ ]`              | extra platform modules                                      |
| `selectionModules`  | no       | `[ ]`              | modules that join the host's in both selection steps        |
| `extraModulesFor`   | no       | `_: [ ]`           | resolved selection -> platform modules                      |
| `system`            | no       | `"x86_64-linux"`   | passed on as the `system` argument only                     |

`mkNixosHost` takes the same plus `nixpkgs`, whose `lib.nixosSystem` it calls,
and returns `{ system, selection, inventory }`, where `system` is the
`nixosSystem` result. `mkNixosModules` returns
`{ modules, specialArgs, selection, inventory }`; `mkNixosHost` adds nothing to
that list, so a caller that wants the modules for something other than
`nixosSystem` (a test node, say) takes them from `mkNixosModules`.

The arguments that need more than a line:

- **`knownHosts`**: a record confined to a host not in it fails as "confined to
  unknown host(s)", so a consumer building several hosts passes every host name
  to each.
- **`specialArgs`** is extended with `system` and `host = hostName` (those two
  win), and the result is what every platform module and every home module
  receives.
- **`system`** is only that argument. The constructor never sets
  `nixpkgs.hostPlatform`: the host's own `nixos`, a selected group's `system.module` or
  an `extraModules` entry sets it, or the host fails to evaluate. The examples
  set it in the host's own `nixos`.
- **`overlays`**: a selected module's overlay is applied before the caller's,
  so inside it `prev` carries none of the caller's packages and reading one
  aborts with a missing attribute. A module therefore builds what it replaces
  with a fresh `callPackage`, naming every argument it needs. A caller's overlay
  that replaces a name a selected module also replaces must step aside for a
  name `prev` already carries, or it overrides the module's value. A matched
  override record's overlay is applied after the modules' and before the
  caller's.
- **`extraModules`** land after the selected modules and before the matched
  records' `system` modules and the host's own `nixos`. A catalogue file listed
  here that the host also selected is two copies of one module, which nixpkgs
  refuses as `already declared`: select it or import it, not both
  ([Dendrites](dendrites.md#what-is-not-a-module)).

## The module list

The platform pass assembles one list, in this order:

```
 1  { nixpkgs.overlays = overlays; }               if overlays != [ ]
 2  { nixpkgs.overlays = <matched records' overlays>; }   if any
 3  habit.selected for the system                  the host's own scope
 4  each user's module, wrapped                    the accounts, and each user's `habit.home`
 5  each selected capability, wrapped              catalogue (name) order, one per capability
 6  Home Manager wiring                            if any user has home.enable
 7  extraModules ++ extraModulesFor selection
 8  each matched override record's `system`
 9  selection.nixos                                the host's `nixos`, merged with selected groups' `system.module`
```

Position is not priority. A scalar defined twice at the same priority
conflicts wherever the two sit; `mkDefault`, `mkForce` and plain definitions
decide. Position shows in list-typed options, whose definitions merge in
reverse list order: the suite pins `nixpkgs.overlays` as the selected modules',
then the matched records', then the caller's (`overlayOrder`), and an
`extraModulesFor` module after a selected module and before a matched record's
`system` module (`extraModulesForKeepsItsPosition`). Overlays apply in that
order and the last to set an attribute wins, so a record's overlay beats a
selected module's, and the caller's beats the record's. The host's own overlays come
first and lose to all of them; a host that must win orders its definition
later, `nixpkgs.overlays = lib.mkAfter [ … ]`.

A home half is not in this list: it is a `home-manager.users.<user>`
definition made by the wrapped module in item 4 or 5, merged by that module's
position, so it comes before the wiring's own per-user imports
([The host record](host-record.md#what-a-users-home-is-made-of)).

The minimal example's list is three entries: `habit.selected`, the wrapped
`ssh` module, the host's `nixos`.

## The two hooks

Two hooks keep the constructor free of any vocabulary as a host record grows
fields it has never heard of. Both default to nothing, and at their defaults
the module list is exactly the one assembled without them.

- **`selectionModules`**: modules that join the host's own in both selection
  steps, so a field they declare is a field the host record can set and the
  gate step can read.
- **`extraModulesFor`**: a function of the resolved selection returning
  platform modules, which is how a gate-pass choice becomes an import without a
  gate-pass body import. Its modules sit with `extraModules`. It is handed the
  whole selection, catalogue values included, so it can `import` a body nothing
  selected; passing selected paths only is the caller's discipline, and the
  suite pins that it is possible (`extraModulesForCanReachTheCatalogue`).

```nix
# a field the constructor does not know, and the import it decides
selectionModules = [
  { options.role = lib.mkOption { type = lib.types.enum [ "server" "laptop" ]; }; }
];
extraModulesFor = selection: lib.optional (selection.role == "laptop") ./laptop.nix;
```

## The inventory

`inventoryOf`, also `mkNixosModules`'s and `mkNixosHost`'s `inventory`, is what
a host resolved, derived from its selection and never maintained by hand. For
the workstation example (paths shortened to the repository root):

```json
{
  "host": "desk",
  "aggregation": [ "desktop" ],
  "dendrites": {
    "bluetooth": { "provider": null, "source": "./examples/workstation/dendrites/bluetooth" }
  },
  "users": {
    "alice": {
      "definition": "./examples/workstation/users/alice.nix",
      "home": true,
      "aggregation": [ "desktop" ],
      "dendrites": {
        "notifications": { "provider": "dunst", "source": "./examples/workstation/dendrites/notifications" }
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
| `dendrites`   | each capability selected for the system: its `provider` and `source`, the catalogue path that answered |
| `users`       | per user: `definition`, `home` (whether Home Manager is on), its groups and its capabilities |
| `overrides`   | the override records that matched this host (`mkNixosModules` only; `inventoryOf` alone has no records to match) |

`printing` is absent: the host switched it off, so it is not part of what the
host is. The inventory says nothing of a module's halves: whether a module has a
home half is known only by importing it, which the inventory never does.

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
  hostModules = [ ./hosts/box.nix ];
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

From a flake, with that file copied to `./box`:

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

`habit.lib.composition` is unapplied; the consumer applies it with the `lib`
its own host evaluation uses, so selection runs on the consumer's lib.
