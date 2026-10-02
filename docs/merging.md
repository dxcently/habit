# Merging registries

A consumer that merges two registries with `//` lets one side silently win
every name both define, and the capability, group or fix that loses is simply
gone. `lib.catalogues` (`lib/catalogues.nix`, a function of `{ lib }`) merges
them and refuses a clash instead.

```
mergeRegistries :: [ source ] -> { catalogue; aggregations; overrides; }

source = { name :: string; catalogue ? {}; aggregations ? {}; overrides ? {}; }
```

## The source

A source is a registry plus the name to blame it by.

| field          | required | type   |
| -------------- | -------- | ------ |
| `name`         | yes      | string, unique among the sources |
| `catalogue`    | no       | attrset; absent means `{ }` |
| `aggregations` | no       | attrset; absent means `{ }` |
| `overrides`    | no       | attrset; absent means `{ }` |

Those four fields and no others: any other field (a misspelt `aggregation`)
would otherwise drop a group without a trace, so it is an error.

## The example

```nix
# examples/merged/shared/registry.nix
{
  catalogue = {
    git = ./dendrites/git;
    ssh = ./dendrites/ssh;
  };
}
```

```nix
# examples/merged/personal/registry.nix — `dev` groups a capability this
# source does not define; the merged registry is where the name resolves.
{
  catalogue = {
    tmux = ./dendrites/tmux;
  };
  aggregations = {
    dev = ./aggregations/dev;
  };
}
```

```nix
# examples/merged/default.nix — two registries, one host.
{
  habit,
  nixpkgs,
  home-manager,
}:
let
  inherit (nixpkgs) lib;
  composition = habit.lib.composition { inherit lib; };
  catalogues = habit.lib.catalogues { inherit lib; };
in
composition.mkNixosHost {
  inherit nixpkgs;
  hostName = "box";
  registry = catalogues.mergeRegistries [
    (import ./shared/registry.nix // { name = "shared"; })
    (import ./personal/registry.nix // { name = "personal"; })
  ];
  hostModules = [ ./hosts/box.nix ];
  nucleus = ./nucleus.nix;
  homeManagerModule = home-manager.nixosModules.home-manager;
}
```

`dev` lives in `personal` and names `git`, which lives in `shared`. Names
resolve in the merged registry, so a group in one source may group
capabilities from another. The host selects `dev` and `ssh` and gets `git`,
`ssh` and `tmux`.

## The result

The result is a registry, ready to hand to the constructor. All three fields
follow the same rule: keyed by name exactly as it is, and a name in more than
one source is an error naming the field, the name and every source defining
it:

```
catalogue names defined by more than one source: 'ssh' by shared and upstream
```

Because a clash is an error, the result does not depend on source order.

Each field is merged on its own, when it is read. A clash is reported by the
field it is in, and a registry whose `overrides` clash still has a readable
`catalogue`. A fault of a whole source (not an attrset, an unknown field, no
name) is reported by whichever field is read first.

## Errors

| fault                                               | message                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------ |
| a source that is not an attrset (a forgotten `import`) | `registry source at position 2 is a null, not an attrset`       |
| a field outside the four                            | `registry source 'typo' has unknown field(s): aggregation; a source takes only name, catalogue, aggregations, overrides` |
| no string `name`                                    | ``registry source at position 2 has no string `name`; every source is named so a clash can say who defined it`` |
| two sources with one name                           | `registry sources share a name: alpha; each source needs its own`  |
| a field present but not an attrset (`catalogue = null`) | ``registry source 'nulled': `catalogue` must be an attrset, got null`` |
| a name in more than one source                      | `catalogue names defined by more than one source: 'notifications' by alpha and gamma and delta` |

Positions count from 1. An unknown field on a source without a usable name is
reported by position.
