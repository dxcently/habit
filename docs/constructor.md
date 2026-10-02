# The constructor

`lib.composition` is `lib/composition.nix`, a function of `{ lib }`. Applied,
it returns:

| name              | does                                                                       |
| ----------------- | -------------------------------------------------------------------------- |
| `mkNixosHost`     | `mkNixosModules` handed to `nixpkgs.lib.nixosSystem`                       |
| `mkNixosModules`  | the platform pass: module list, `specialArgs`, selection, inventory        |
| `evalSelection`   | `{ registry, modules }` -> resolved selection (gate, then select)          |
| `inventoryOf`     | `{ hostName, selection }` -> what the host resolved; the review surface    |
| `lanesFor`, `implOf`, `overridesFor`, `mkSchema`, `laneNames` | the pieces, for callers that assemble differently |

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
| `nucleus`           | yes      |                    | the module every host imports unconditionally               |
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
  `nixpkgs.hostPlatform`: the `nucleus` or the host's own `nixos` sets it, or
  the host fails to evaluate. The examples set it in their nucleus.
- **`overlays`**: a lane's overlay is applied before the caller's, so inside a
  lane's overlay `prev` carries none of the caller's packages and reading one
  aborts with a missing attribute. A lane therefore builds what it replaces with
  a fresh `callPackage`, naming every argument it needs. A caller's overlay that
  replaces a name a lane also replaces must step aside for a name `prev`
  already carries, or it overrides the lane's value. A matched override
  record's overlay is applied after the caller's.
- **`extraModules`** land after the lanes and before override modules and the
  host's own `nixos`.

### The whole-tree refusal

An `extraModules` path, or one returned by `extraModulesFor`, that is the
directory holding catalogue entries (an aggregate whose `default.nix` imports
every capability's body), together with any selected capability, is refused by
name. Both would import the same body, so its options would be declared twice
and nixpkgs would throw `already declared`. Keep one: take the whole directory
and select nothing, or select through the catalogue and drop the aggregate.

## The module list

The platform pass assembles one list, in this order:

```
 1  nucleus
 2  { nixpkgs.overlays = overlays; }               if overlays != [ ]
 3  each user definition's `nixos` lane            the accounts
 4  each selected capability's `nixos` lane        catalogue (name) order
 5  Home Manager wiring                            if any user has homeManager.enable
 6  extraModules ++ extraModulesFor selection
 7  each matched override record's `nixos`
 8  { nixpkgs.overlays = mkAfter <matched records' overlays>; }   if any
 9  selection.nixos                                the host's `nixos`, merged with selected groups' `nixos`
```

Position is not priority. A scalar defined twice at the same priority
conflicts wherever the two sit; `mkDefault`, `mkForce` and plain definitions
decide. Position shows in list-typed options, whose definitions merge in
reverse list order: the suite pins `nixpkgs.overlays` as lane, then caller,
then nucleus, then the matched records' (`overlayOrder`), and an
`extraModulesFor` module after a matched record's `nixos`
(`extraModulesForKeepsItsPosition`). Entry 8 is `mkAfter`, which is why a
record's overlay is applied last and wins over a lane's, the caller's and the
nucleus's on a shared attribute.

The minimal example's list is three entries: the nucleus, the `ssh` lane, the
host's `nixos`.

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
      "homeManager": true,
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
| `users`       | per user: `definition`, `homeManager`, its groups and its capabilities  |
| `overrides`   | the override records that matched this host (`mkNixosModules` only; `inventoryOf` alone has no records to match) |

`printing` is absent: the host switched it off, so it is not part of what the
host is.

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
  nucleus = ./nucleus.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

From a flake, with that file copied to `./box`:

```nix
nixosConfigurations.box = (import ./box { inherit habit nixpkgs home-manager; }).system;
```

`habit.lib.composition` is unapplied; the consumer applies it with the `lib`
its own host evaluation uses, so selection runs on the consumer's lib.
