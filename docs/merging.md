# Merging registries

A consumer that merges two registries with `//` lets one side silently win
every name both define, and the capability, group or fix that loses is simply
gone. `lib.catalogues` (`lib/catalogues.nix`, a function of `{ lib }`) merges
them and refuses a clash instead.

```
mergeRegistries :: [ source ] -> { catalogue; aggregations; overrides; rules; ruleFrom; }

source = { name :: string; catalogue ? {}; aggregations ? {}; overrides ? {}; rules ? {}; }
```

## The source

A source is a registry plus the name to blame it by.

| field          | required | type   |
| -------------- | -------- | ------ |
| `name`         | yes      | string, unique among the sources |
| `catalogue`    | no       | attrset; absent means `{ }` |
| `aggregations` | no       | attrset; absent means `{ }` |
| `overrides`    | no       | attrset; absent means `{ }` |
| `rules`        | no       | attrset; absent means `{ }` ([Registry rules](rules.md)) |

Those five fields and no others: any other field (a misspelt `aggregation`)
would otherwise drop a group without a trace, so it is an error.

## The example

[`examples/full`](https://github.com/dxcently/habit/tree/main/examples/full) merges
two sources. The core registry is the flake's own modules, and the personal one
adds `tmux` and a group, `dev`, that names `git` from core and `tmux` from itself.

```nix
# examples/full/modules/default.nix — the core registry; personal/ adds a second one.
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          imports = [ ./dendrites/shell/prompt.nix ];
          programs.fish.enable = true;
          habit.home = {
            imports = [ ./dendrites/shell/prompt-home.nix ];
            programs.fish.enable = true;
          };
        };
      };
    };
    terminal = {
      providers = {
        kitty = ./dendrites/terminal/kitty.nix;
        foot = ./dendrites/terminal/foot.nix;
      };
    };
    git = ./dendrites/git.nix;
    ssh = ./dendrites/ssh.nix;
  };
  aggregations = {
    base = ./aggregations/base;
    terminal = ./aggregations/terminal;
  };
  overrides = {
    zsh-quiet-compaudit = ./overrides/zsh-quiet-compaudit.nix;
  };
}
```

```nix
# examples/full/modules/personal/default.nix — a second registry; `dev` groups `git`, from the core registry, and `tmux`, which lives here.
{
  catalogue = {
    tmux = ./dendrites/tmux.nix;
  };
  aggregations = {
    dev = ./aggregations/dev;
  };
  overrides = { };
}
```

`dev` lives in `personal` and names `git`, which lives in `core`. Names resolve
in the merged registry, so a group in one source may group capabilities from
another. `desk` selects `dev` and gets `git` and `tmux`, and `ssh` comes from
`base`. The flake merges the two and hands the result to both hosts and the
standalone home:

```nix
# examples/full/flake.nix
{
  description = "A desk, a server and a standalone home, one registry and two sources: the habit template";

  inputs = {
    habit.url = "github:dxcently/habit";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    habit.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      habit,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      composition = habit.lib.composition { inherit lib; };
      catalogues = habit.lib.catalogues { inherit lib; };
      registry = catalogues.mergeRegistries [
        (import ./modules/default.nix // { name = "core"; })
        (import ./modules/personal/default.nix // { name = "personal"; })
      ];
      nixosHost =
        name:
        (composition.mkNixosHost {
          inherit nixpkgs registry;
          hostName = name;
          host = ./hosts + "/${name}/default.nix";
          homeManagerModule = home-manager.nixosModules.home-manager;
        }).system;
    in
    {
      nixosConfigurations = {
        desk = nixosHost "desk";
        server = nixosHost "server";
      };

      homeConfigurations.alice =
        (composition.mkHome {
          inherit home-manager registry;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          hostName = "alice";
          host = ./hosts/alice/default.nix;
        }).home;
    };
}
```

## The result

The result is a registry, ready to hand to the constructor. All four fields
follow the same rule: keyed by name exactly as it is, and a name in more than
one source is an error naming the field, the name and every source defining
it:

```
catalogue names defined by more than one source: 'ssh' by core and upstream
```

Because a clash is an error, the result does not depend on source order.

`ruleFrom` maps each rule name to the source that defined it, so a rule's
error can name its registry. It is read by the constructor and by nothing else.

Each field is merged on its own, when it is read. A clash is reported by the
field it is in, and a registry whose `overrides` clash still has a readable
`catalogue`. A fault of a whole source (not an attrset, an unknown field, no
name) is reported by whichever field is read first.

## Errors

| fault                                               | message                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------ |
| a source that is not an attrset (a forgotten `import`) | `registry source at position 2 is a null, not an attrset`       |
| a field outside the five                            | `registry source 'typo' has unknown field(s): aggregation; a source takes only name, catalogue, aggregations, overrides, rules` |
| no string `name`                                    | ``registry source at position 2 has no string `name`; every source is named so a clash can say who defined it`` |
| two sources with one name                           | `registry sources share a name: alpha; each source needs its own`  |
| a field present but not an attrset (`catalogue = null`) | ``registry source 'nulled': `catalogue` must be an attrset, got null`` |
| a name in more than one source                      | `catalogue names defined by more than one source: 'notifications' by alpha and gamma and delta` |

Positions count from 1. An unknown field on a source without a usable name is
reported by position.
