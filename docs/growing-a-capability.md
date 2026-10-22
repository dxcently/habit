# Growing a capability

One capability, `shell`, grown from one file to a provider set with a home
half, a piece two providers share, a terminal that reads it, and an override.
Each step builds on the one before, and each is a complete flake
under [`examples/steps`](https://github.com/dxcently/habit/tree/main/examples/steps).
The forms a capability can take, each with the step that shows it, are on
[What a capability can be](forms.md).

| step | adds | the form it shows |
| --- | --- | --- |
| [1](#1-one-file) | a file | a plain module, selected by name |
| [2](#2-a-home-half) | a directory, `habit.home`, a user | a module with a home half, and files beside it |
| [3](#3-providers) | two providers and a value | a provider set, as files and as a value |
| [4](#4-users) | a second user, who opts out; a host that picks no shell | per-user homes, an opt-out, and a user's own provider |
| [5](#5-terminal) | `terminal` and a group | a group, and a module that reads `habit.selected` |
| [6](#6-override) | an override record, and a second host | a fix that belongs to `shell` |
| [7](#7-shared) | a piece two providers share | the two-file pattern |

## 1. One file

A capability that is one NixOS module needs nothing else. The registry names
the file, and a host selects it by name.

```nix
# examples/steps/1-file/flake.nix
{
  description = "habit, step 1: one capability, one file";

  inputs = {
    habit.url = "github:dxcently/habit";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    habit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { habit, nixpkgs, ... }:
    let
      composition = habit.lib.composition { inherit (nixpkgs) lib; };
    in
    {
      nixosConfigurations.desk =
        (composition.mkNixosHost {
          inherit nixpkgs;
          hostName = "desk";
          registry = import ./modules/default.nix;
          host = ./hosts/desk/default.nix;
        }).system;
    };
}
```

```nix
# examples/steps/1-file/modules/default.nix
{
  catalogue = {
    shell = ./dendrites/shell.nix;
  };
  aggregations = { };
  overrides = { };
}
```

```nix
# examples/steps/1-file/modules/dendrites/shell.nix
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
```

```nix
# examples/steps/1-file/hosts/desk/default.nix
{
  habit.dendrites.shell.enable = true;

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

habit imports the file only because `desk` selected it, and its whole
configuration is the system half.

## 2. A home half

Part of the capability belongs in a user's home, and it wants a plain file
beside it. The entry becomes a directory: its `default.nix` is the module, and
`habit.home` is the part a user's Home Manager configuration receives. The flake
gains the `home-manager` input for it.

```nix
# examples/steps/2-home/flake.nix
{
  description = "habit, step 2: a capability with a home half";

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
      composition = habit.lib.composition { inherit (nixpkgs) lib; };
    in
    {
      nixosConfigurations.desk =
        (composition.mkNixosHost {
          inherit nixpkgs;
          hostName = "desk";
          registry = import ./modules/default.nix;
          host = ./hosts/desk/default.nix;
          homeManagerModule = home-manager.nixosModules.home-manager;
        }).system;
    };
}
```

```nix
# examples/steps/2-home/modules/default.nix
{
  catalogue = {
    shell = ./dendrites/shell;
  };
  aggregations = { };
  overrides = { };
}
```

```nix
# examples/steps/2-home/modules/dendrites/shell/default.nix
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  habit.home = {
    programs.zsh = {
      enable = true;
      shellAliases = import ./aliases.nix;
    };
  };
}
```

```nix
# examples/steps/2-home/modules/dendrites/shell/aliases.nix
{
  ll = "ls -l";
  la = "ls -a";
}
```

```nix
# examples/steps/2-home/hosts/desk/default.nix
{
  habit.dendrites.shell.enable = true;

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

```nix
# examples/steps/2-home/users/alice.nix
{
  users.users.alice.isNormalUser = true;
}
```

habit puts `habit.home` into `alice`'s Home Manager configuration, since alice is
a user with `home.enable = true`. The system half stays on the host, and
`aliases.nix` is an ordinary file the home half reads.

## 3. Providers

The capability has more than one implementation, and a system takes one. Its
entry becomes a provider set. Here the set is written in the registry, `bash`
and `zsh` are files, and `fish` is a module value written in place.

```nix
# examples/steps/3-providers/modules/default.nix
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          programs.fish.enable = true;
          habit.home.programs.fish.enable = true;
        };
      };
    };
  };
  aggregations = { };
  overrides = { };
}
```

```nix
# examples/steps/3-providers/modules/dendrites/shell/zsh.nix
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  habit.home = {
    programs.zsh = {
      enable = true;
      shellAliases = import ./aliases.nix;
    };
  };
}
```

```nix
# examples/steps/3-providers/modules/dendrites/shell/bash.nix
{
  programs.bash.completion.enable = true;

  habit.home = {
    programs.bash.enable = true;
  };
}
```

```nix
# examples/steps/3-providers/hosts/desk/default.nix
{
  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

`zsh.nix` is the old `shell/default.nix` with its home half unchanged; the
`aliases.nix` beside it did not move. The set could as well be a file, a
`dendrites/shell/default.nix` holding the same `providers` attrset, with the
registry entry `shell = ./dendrites/shell;`. A value is for a set whose inputs are
in scope where it is written; a hand-written set is a file
([Several providers](dendrites.md#several-providers)).

habit reads the set, then reads only the target `desk` chose. `bash.nix` and the
`fish` value are never read for `desk`, which the suite proves with a file that
throws in their place.

## 4. Users

Alice and bob both get a home on `desk`. The host picks zsh, so zsh holds the
system half. Alice names fish for their own home, and bob opts out of the shell's
home half.

```nix
# examples/steps/4-users/hosts/desk/default.nix
{
  habit.dendrites.shell = {
    enable = true;
    provider = "zsh";
  };

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
    dendrites.shell.provider = "fish";
  };

  habit.users.bob = {
    definition = ../../users/bob.nix;
    home.enable = true;
    dendrites.shell.enable = false;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

```nix
# examples/steps/4-users/users/bob.nix
{
  users.users.bob.isNormalUser = true;
}
```

Alice's `dendrites.shell.provider = "fish";` is one line. It selects `shell` for
Alice, since naming a provider implies enable. The host holds the system half with
zsh, so Alice's fish is Alice's home alone: Alice gets fish in Alice's Home Manager, and the
system keeps zsh. Bob's opt-out withholds only Bob's home half, so Bob gets no zsh
home, and the system still has zsh.

```
desk
├── system ─────────── zsh     the host's, which holds the system half
├── alice's home ───── fish    own provider, home only
└── bob's home ─────── none    opted out of the shell's home half
```

Each scope's `habit.selected` reports its own selection: the system's names zsh,
and alice's names fish.

The limit is the system half. With the host selecting no shell, a user's
provider takes the system half, since nothing else holds it. Two users who name
different providers then both want it, and the build refuses, naming each
claimant and both fixes:

```
dendrite 'shell' is wanted with different providers for its system half (user 'alice': 'fish'; user 'bob': 'zsh'); one system takes one implementation. ...
```

A different provider for the whole system is a different system: a standalone
home has its own selection, as [`examples/full`](#the-full-example) shows.

## 5. Terminal

A second capability reads what the first selected, and a group names both at
once. `terminal` has two providers, `kitty` and `foot`, and the `terminal` group
selects it with `shell` and their defaults.

```nix
# examples/steps/5-terminal/modules/default.nix
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          programs.fish.enable = true;
          habit.home.programs.fish.enable = true;
        };
      };
    };
    terminal = {
      providers = {
        kitty = ./dendrites/terminal/kitty.nix;
        foot = ./dendrites/terminal/foot.nix;
      };
    };
  };
  aggregations = {
    terminal = ./aggregations/terminal;
  };
  overrides = { };
}
```

```nix
# examples/steps/5-terminal/modules/aggregations/terminal/default.nix
{
  description = "A terminal, and the shell it launches.";

  system = {
    providers = {
      shell = "zsh";
      terminal = "kitty";
    };
  };

  home = {
    providers = {
      shell = "zsh";
      terminal = "kitty";
    };
  };
}
```

```nix
# examples/steps/5-terminal/modules/dendrites/terminal/kitty.nix
{
  habit.home =
    { config, lib, ... }:
    let
      shell = config.habit.selected.shell;
    in
    {
      programs.kitty = {
        enable = true;
        settings = lib.optionalAttrs shell.enable { shell = shell.provider; };
      };
    };
}
```

```nix
# examples/steps/5-terminal/modules/dendrites/terminal/foot.nix
{
  habit.home =
    { config, lib, ... }:
    let
      shell = config.habit.selected.shell;
    in
    {
      programs.foot = {
        enable = true;
        settings = lib.optionalAttrs shell.enable { main.shell = shell.provider; };
      };
    };
}
```

`kitty.nix` names no `shell`. Its home half reads `config.habit.selected.shell`
from the user's own home, where the shell the group sent is selected, so kitty
launches the shell that user has. `optionalAttrs` keeps the setting out when the user opted out of the shell,
so kitty then starts its own default.

`desk` selects the group, and alice keeps the fish named in step 4.

```nix
# examples/steps/5-terminal/hosts/desk/default.nix
{
  habit.aggregation.terminal.enable = true;

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
    dendrites.shell.provider = "fish";
  };

  habit.users.bob = {
    definition = ../../users/bob.nix;
    home.enable = true;
    dendrites.shell.enable = false;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

## 6. Override

A fix belongs to `shell`, wherever `shell` is selected, and not to any one host.
An override record names the capability it is about. This step adds `server`,
which selects zsh, so the override reaches a second host. A host that selects no
shell is left alone, as the real-platform suite checks with a host of that kind.

```nix
# examples/steps/6-override/modules/default.nix
{
  catalogue = {
    shell = {
      providers = {
        bash = ./dendrites/shell/bash.nix;
        zsh = ./dendrites/shell/zsh.nix;
        fish = {
          programs.fish.enable = true;
          habit.home.programs.fish.enable = true;
        };
      };
    };
    terminal = {
      providers = {
        kitty = ./dendrites/terminal/kitty.nix;
        foot = ./dendrites/terminal/foot.nix;
      };
    };
  };
  aggregations = {
    terminal = ./aggregations/terminal;
  };
  overrides = {
    zsh-quiet-compaudit = ./overrides/zsh-quiet-compaudit.nix;
  };
}
```

```nix
# examples/steps/6-override/modules/overrides/zsh-quiet-compaudit.nix
{
  dendrites = [ "shell" ];

  system = {
    environment.variables.ZSH_DISABLE_COMPFIX = "true";
  };
}
```

The record's `system` module applies once to each host that selected `shell`
with `system = true`. A host that selects no shell is untouched: its
`environment.variables` has no `ZSH_DISABLE_COMPFIX`, which `tests/real/nixos.nix`
checks on a host of that kind.

## 7. Shared

Two providers need the same piece, with a system half and a home half. The
piece is two files, one per half, and each provider imports both by path.

```nix
# examples/steps/7-shared/modules/dendrites/shell/prompt.nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.starship ];
}
```

```nix
# examples/steps/7-shared/modules/dendrites/shell/prompt-home.nix
{
  programs.starship.enable = true;
}
```

```nix
# examples/steps/7-shared/modules/dendrites/shell/zsh.nix
{ pkgs, ... }:
{
  imports = [ ./prompt.nix ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  habit.home = {
    imports = [ ./prompt-home.nix ];

    programs.zsh = {
      enable = true;
      shellAliases = import ./aliases.nix;
    };
  };
}
```

The fish value imports the same two files from the registry:

```nix
# examples/steps/7-shared/modules/default.nix
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
  };
  aggregations = {
    terminal = ./aggregations/terminal;
  };
  overrides = {
    zsh-quiet-compaudit = ./overrides/zsh-quiet-compaudit.nix;
  };
}
```

The host's zsh holds the system half, so the system file lands once, from zsh.
Alice's fish is Alice's home alone, so the fish value's system import is not applied,
and only its home file lands in Alice's home. Naming the
home file as a bare path, or importing the system file inline, makes the options
declared twice; that trap is in
[A piece several entries share](dendrites.md#a-piece-several-entries-share).

Step 7 is step 6 with that change and nothing else: `diff -r` of the two
directories shows the shared piece, and the override stays.

## The full example

[`examples/full`](https://github.com/dxcently/habit/tree/main/examples/full) is
these seven steps as one flake, laid out as a repository: a desk, a standalone home,
two users, a second registry merged in, and the override. `nix flake init -t
github:dxcently/habit` copies it. Its desk reads like a config someone keeps:

```nix
# examples/full/hosts/desk/default.nix
{
  habit.aggregation.base.enable = true;
  habit.aggregation.terminal.enable = true;
  habit.aggregation.dev.enable = true;

  habit.users.alice = {
    definition = ../../users/alice.nix;
    home.enable = true;
  };

  habit.users.bob = {
    definition = ../../users/bob.nix;
    home.enable = true;
    dendrites.shell.enable = false;
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

`ssh` lives in `base`, which every machine carries. `dev` is the second
registry's group: it names `git`, which the core registry defines, and `tmux`,
which the personal registry does, so one group reaches across both sources and
the desk switches nothing off. The standalone home takes its own `fish`
provider, which is the per-user choice a shared system cannot make.

The server is [`hosts/server`](https://github.com/dxcently/habit/blob/main/examples/full/hosts/server/default.nix),
the minimal server example: `base` and zsh, nothing else.
