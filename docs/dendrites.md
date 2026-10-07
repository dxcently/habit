# Dendrites

A dendrite is one capability: a name in the registry's `catalogue` and the file
or directory that answers it.

```nix
catalogue = {
  ssh = ./dendrites/ssh.nix;                   # a file
  notifications = ./dendrites/notifications;   # or a directory with default.nix
};
```

[`examples/minimal`](https://github.com/dxcently/habit/tree/main/examples/minimal)
uses the file form, [`examples/workstation`](https://github.com/dxcently/habit/tree/main/examples/workstation)
the directory form.

The catalogue holds names and paths only. An entry is `import`ed in the
platform pass, and only when some scope enabled it.

## A plain module

A single-implementation dendrite is an ordinary NixOS module, written the way
any module is: an attrset, a function of `{ config, lib, pkgs, ... }`, or one
with `options` and `config`. It may declare options of its own; habit declares
none in a module's namespace.

```nix
# examples/minimal/dendrites/ssh.nix
{
  services.openssh.enable = true;
}
```

habit imports the file when a scope selects it and splits it into two halves:

| half   | is                                     | applied in                                   |
| ------ | -------------------------------------- | -------------------------------------------- |
| system | the module as written, minus `habit`   | the host's evaluation                        |
| home   | the value of `habit.home`              | the Home Manager configuration of each user it reaches |

A module with no `habit.home` has an empty home half, and one with only
`habit.home` has an empty system half. Selecting either where it has nothing to
say applies the empty half and fails nothing. A module that is not a set (a
string, a list) is refused, naming the file ([Errors](errors.md#modules)).

## The home half

Settings for a user's Home Manager configuration go in `habit.home`:

```nix
# examples/workstation/dendrites/notifications/dunst.nix
{
  habit.home = {
    services.dunst.enable = true;
  };
}
```

`habit.home` is a module of its own: an attrset, or a function of Home
Manager's `{ config, lib, pkgs, ... }`. `habit` is not an option anywhere;
habit reads it out of the module's top-level configuration, through `mkIf`,
`mkMerge` and `mkOverride` wrappers without evaluating their conditions, and
removes it before the module system sees the rest. So:

- only `habit.home` is read; any other `habit` key (`habit.homee`, or a
  selection such as `habit.dendrites.kitty.enable`, which only the host makes) is
  an error naming the file, and so is a `habit` that is itself behind `mkIf`;
- a module's `imports` belong to the system half; imports for the home half go
  inside `habit.home`, and a file the module imports that writes `habit.home`
  fails as an option that does not exist, naming that file;
- the module's own head (`{ config, lib, ... }:`) is the system's, so reading
  `config` there reads NixOS options; `habit.home = { config, lib, ... }: ...`
  binds Home Manager's own `config` and its `lib`, extended with `lib.hm`;
- the home half is a definition of `home-manager.users.<user>`, emitted only for
  users it reaches, so a host without a Home Manager user never mentions
  `home-manager` at all.

## Halves and scopes

Who selected a module decides where its halves go:

| selected by       | system half | home half goes to                              |
| ----------------- | ----------- | ---------------------------------------------- |
| the host          | applied     | every user with `home.enable = true`           |
| user `U`          | applied     | `U` only                                       |
| the host and `U`  | applied once | `U` once                                      |

A user's selection applies the system half as well, because some modules need
both sides (a screen locker's PAM service). A module reached by several
selections is wrapped once, so its system half is applied once however many
users chose it, and each user's home gets the half once.
A user with `home.enable = false` receives no home half; selecting a module
for that user's home is an error
([Errors](errors.md#users)).

## Reading the selection

`habit.selected.<name>` is a read-only option in every evaluation: the host's
evaluation holds what the host selected, and each user's Home Manager
configuration holds what that user selected. A module can react to what else
was selected without importing it:

```nix
{ config, ... }:
{
  services.greetd.enable = config.habit.selected.compositor.enable;
}
```

`habit.selected` is one key of the `habit` option, beside the keys the host sets
under it ([The host module](host.md)), which the platform evaluation declares
inert. Each entry is `{ enable : bool; provider : null or string; }` for every
catalogue name; an unselected name is `{ enable = false; provider = null; }`.
It is written from the resolved selection and never reads configuration, so it
cannot recurse into the selection. Defining it anywhere else (an
`extraModules` entry, a user's `home.config`) is refused by the module system as
read-only ([Errors](errors.md#from-the-module-system)); a dendrite that writes
`habit.selected` is refused by habit as an unknown `habit` key.

## Several providers

A capability with more than one implementation is a provider set. The entry is
data naming provider files, and each provider file is a plain module of its
own.

```nix
# examples/workstation/dendrites/notifications/default.nix — two providers;
# only the chosen file is ever read.
{
  providers = {
    dunst = ./dunst.nix;
    mako = ./mako.nix;
  };
}
```

```nix
# examples/workstation/dendrites/notifications/mako.nix
{
  habit.home = {
    services.mako.enable = true;
  };
}
```

The entry file is read when the capability is enabled; of its provider files,
only the chosen one is ever imported. One system takes one implementation of a
capability: the host and every user that select it must name the same
provider, and a selector that names another is an error naming every claimant
([Errors](errors.md#selecting-capabilities)).

| selection                                     | result                                                     |
| --------------------------------------------- | ---------------------------------------------------------- |
| enabled, `provider = "dunst"`                 | `dunst.nix` is imported; `mako.nix` is never read          |
| enabled, no provider                          | error naming the available providers                       |
| enabled, `provider = "nope"`                  | error naming the available providers                       |
| single implementation, any `provider`         | error: it takes no provider                                |

A provider is chosen with `habit.dendrites.<name>.provider`, or under the
aggregation that groups it ([Aggregations](aggregations.md#choosing-a-provider)).

## What is not a module

A set of named lanes (`{ body; nixos; homeManager; }`) is not read as anything
special: it is a module whose top-level keys are configuration for options
called `body`, `nixos` and `homeManager`, so it fails where the host's system
half is evaluated, as an option that does not exist, naming the file.

A catalogue file that is also imported by hand (`extraModules`) is two copies of
one module, one wrapped and one not. They share no key, so nothing
de-duplicates them, and a module that declares options fails as `already
declared`. Select it or import it, not both.

## The inventory names the answer

The inventory records, per selected capability, its provider and `source`: the
catalogue path that answered. See
[The constructor](constructor.md#the-inventory).
