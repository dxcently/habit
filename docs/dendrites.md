# Dendrites

A dendrite is one capability: a name in the registry's `catalogue` and the file,
directory or module value that answers it.

```nix
catalogue = {
  ssh = ./dendrites/ssh.nix;                   # a file
  notifications = ./dendrites/notifications;   # or a directory with default.nix
};
```

[Growing a capability](growing-a-capability.md) shows the file form in
[step 1](growing-a-capability.md#1-one-file), the directory form in
[step 2](growing-a-capability.md#2-a-home-half) and the provider set in
[step 3](growing-a-capability.md#3-providers).

The catalogue holds names and entries only. A path entry is `import`ed in the
platform pass, and only when some scope enabled it; a module value is applied
there under the same condition ([Value entries](#value-entries)).

## A plain module

A single-implementation dendrite is an ordinary NixOS module, written the way
any module is: an attrset, a function of `{ config, lib, pkgs, ... }`, or one
with `options` and `config`. It may declare options of its own; habit declares
none in a module's namespace.

```nix
# examples/steps/1-file/modules/dendrites/shell.nix
{ pkgs, ... }:
{
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
```

habit imports the file when a scope selects it and splits it into two halves:

| half   | is                                     | applied in                                   |
| ------ | -------------------------------------- | -------------------------------------------- |
| system | the module as written, minus `habit`   | the host's evaluation (NixOS or nix-darwin)  |
| home   | the value of `habit.home`              | the Home Manager configuration of each user it reaches, or the standalone home itself |

A module with no `habit.home` has an empty home half, and one with only
`habit.home` has an empty system half. Selecting either where it has nothing to
say applies the empty half and fails nothing. A module that is not a set (a
string, a list) is refused, naming the file ([Errors](errors.md#modules)).

## The home half

Settings for a user's Home Manager configuration go in `habit.home`:

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

`habit.home` is a module of its own: an attrset, a function of Home
Manager's `{ config, lib, pkgs, ... }`, or a path to one. `habit` is not an option anywhere;
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
- the home half is a module defined for `home-manager.users.<user>`, emitted
  only for users it reaches, so a host without a Home Manager user never
  mentions `home-manager` at all. A `mkIf` around `habit.home`, or around the
  module's configuration, at any depth, is emitted outside the user's module as
  `home-manager.users.<user> = mkIf c <module>`: the platform discharges it for
  that definition, as it does a `mkIf` on any option of `attrsOf` type, so a
  false condition defines nothing in the user's Home Manager. `mkIf false {
  habit.home.stylix.enable = true; }` is safe where Home Manager does not
  declare `stylix`, and a condition may cover the half's `imports` and option
  declarations too, since the whole module is withheld. The condition is
  evaluated in the system evaluation, above the user's home: it may read the
  system's `config`, but not `config.home-manager.users.<user>.*`, which
  recurses. A `mkOverride` is carried down to what the half sets instead: the
  definition of the user holds no priority, so one module's priority never
  filters another's home half for the same user. Write `mkIf` outside `mkOverride` (`mkIf c (mkOverride p x)`),
  as nixpkgs itself requires: the other order fails in the module system. In a
  standalone home there is no `home-manager.users`: the half is imported into
  the home itself, and a `mkIf` and a `mkOverride` are both carried down to what
  the half sets, as in any Home Manager module, so a false `mkIf` still defines
  what it covers and an option Home Manager does not declare is an error there.
  A condition cannot cover the `imports` or option declarations of a half in a
  standalone home, which are read before any condition is, so a half under one
  that carries either is refused, naming the module. The module's own head is
  then Home Manager's, so a module meant for both reads only its own options and
  `habit.selected` there, never another module's system option.

## Halves and scopes

Who selected a module decides where its halves go:

| selected by                       | system half                | home half goes to                              |
| --------------------------------- | -------------------------- | ---------------------------------------------- |
| the host                          | applied                    | every user with `home.enable = true`           |
| the host, `system = false`        | not applied                | every user with `home.enable = true`           |
| user `U`                          | applied                    | `U` only                                       |
| user `U`, `system = false`        | not applied                | `U` only                                       |
| the host and `U`                  | applied once               | `U` once                                       |
| the host and `U`, both `system = false` | not applied          | `U` once                                       |
| the host, `system = false`, and `U` | applied once             | `U` once                                       |
| the host, `zsh`, and `U`, `fish`  | applied, `zsh` (the host's) | `U` gets `fish`; every other home user gets `zsh` |
| a standalone home                 | dropped, `imports` with it | the home itself                                |

A user withholds the home half the host sent it with `enable = false`, and a
host-selected dendrite's home half reaches every user with a home except those
that opted out ([Opting out](host.md#opting-out)):

| selected by                                         | system half       | home half goes to                              |
| --------------------------------------------------- | ----------------- | ---------------------------------------------- |
| the host, and user `U` writes `enable = false`      | applied           | every user with `home.enable = true` except `U` |
| a host-selected group, and user `U` writes `enable = false` for the member | applied, as the host's (whatever the users do) | every user with a home except `U` |

A selection's `system` says whether it asks for the module's system half. A
host's is `true` by default. A user's is unset, which asks, unless the host turned
the half off with `system = false`: then an unset user is home only, and only an
explicit `system = true` takes it. The system half is applied by the one provider
that holds it: the host's, when the host asks, and otherwise the provider every
asking user names ([Several providers](#several-providers)).
Where the home half goes does not depend on it. A user's selection applies the
system half by default because some modules need both sides (a screen locker's
PAM service). A module reached by several selections is wrapped once per
provider, so its system half is applied once however many users chose it, and
each user's home gets the half once. A user with `home.enable = false` receives
no home half; selecting a module for that user's home is an error
([Errors](errors.md#users)).

`system = false` is written beside `enable` in either scope:

```nix
habit.dendrites.kitty = { enable = true; system = false; };
habit.users.alice.dendrites.kitty = { enable = true; system = false; };
```

It is accepted in a standalone home and changes nothing, since a home never
applies the system half. A group's members write only `enable` and `provider`
(at `mkDefault`), so a host switches a member to its home half with
`habit.dendrites.<member>.system = false`. An override record's `system` module
follows its target's system half: it is not applied for a target every one of
whose selections has `system = false`. Its `overlay` and `home` module do not
depend on it ([Override records](overrides.md#matching)).

A module selected only with `system = false` still declares its own `options` in
the system evaluation; only its `config` and `imports` are dropped.

Two refusals keep `system = false` honest ([Errors](errors.md#modules)): a
module with no `habit.home` has no home half to select, whichever scope or
provider asked, a user's provider that the host's system half displaces to the
home alone included; and the host's own `system = false`, on a host where no user has
`home.enable = true`, has no home to receive the half.

A home half configures `$HOME`. A bare package belongs in the system half
(`environment.systemPackages`), and a capability meant for "the system or the
home" is written with both halves and selected with `system = false` where only
the home is wanted. Take care with a module whose home half needs its system
half: a screen locker whose PAM service lives in the system half is broken
by `system = false`, since the home half configures the program and the system
half is what lets it authenticate.

## Darwin

habit has no declaration of which platforms a module supports. A module is
written the way nixpkgs teaches (guard a Linux-only setting with `mkIf
pkgs.stdenv.isLinux`, or keep the file Linux-only), and one that reaches a
nix-darwin host with an option nix-darwin does not have fails as the module
system's own error, naming the module's file (a catalogue entry that is a
directory is the `default.nix` inside it):

```
error: The option `services' does not exist. Definition values:
- In `/path/to/dendrites/linuxOnly/default.nix':
```

The message says the option does not exist, not that the module has no darwin
support: the module system raises it for the whole evaluation, after every
module has been merged, so habit cannot catch it for one module.

## Reading the selection

`habit.selected.<name>` is a read-only option in every evaluation: the host's
evaluation holds what the host selected, and each user's Home Manager
configuration holds what that user selected. A standalone home holds what it
selected. A module can react to what else
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
data naming its providers, and each provider is a plain module of its own: a
file, or a module value ([Value entries](#value-entries)).

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
# examples/steps/3-providers/modules/dendrites/shell/bash.nix
{
  programs.bash.completion.enable = true;

  habit.home = {
    programs.bash.enable = true;
  };
}
```

Here the set is written as a catalogue value, an attrset whose only key is
`providers`, where the registry that writes it has its inputs in scope. A target
in it is a path or a module value, as in a file. Written as a file instead, the
same attrset is `dendrites/shell/default.nix`, with `shell = ./dendrites/shell;`
in the registry.

A file and a value that hold the same attrset are the same provider set. A set with
`providers` and any other key is refused, in a file or a value, naming the
capability and the keys, since they would be dropped without a word.

The entry is read when the capability is enabled. Of its targets, only the chosen
one is read: a path is imported and a module value is applied, and the rest are
never read, so a target that throws sits unchosen harmlessly. The set's
`providers` attribute is read only when the capability is enabled; an unselected
set's `providers` is never forced. A target may not itself be a provider set. One
system takes one implementation of a capability. The host's provider holds the
system half when the host selects it, and a user who names another provider gets
that provider's home alone. Where the host selects nothing, the users who ask for
the system half must name one provider between them: two that name different
ones are refused, naming each claimant
([Errors](errors.md#selecting-capabilities)).

| selection                                     | result                                                     |
| --------------------------------------------- | ---------------------------------------------------------- |
| enabled, `provider = "bash"`                 | `bash.nix` is imported; `zsh` is never read                |
| enabled, `provider = "fish"`, a module value  | the value is applied; `bash.nix` is never read             |
| enabled, no provider                          | error naming the available providers                       |
| enabled, `provider = "nope"`                  | error naming the available providers                       |
| enabled, a set with a key besides `providers` | error naming the capability and the keys                   |
| single implementation, any `provider`         | error: it takes no provider                                |

A provider is chosen with `habit.dendrites.<name>.provider`, or under the
aggregation that groups it ([Aggregations](aggregations.md#choosing-a-provider)).

## A piece several entries share

A piece that more than one entry needs, and that has both a system half and a
home half, is written as two files: a system module and a Home Manager module.
Each entry that needs it imports the first, and names the second in its own
`habit.home.imports`:

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

The piece is `prompt.nix` and `prompt-home.nix`, and each provider that needs it
names both: `imports` for the system half, `habit.home.imports` for the home half.
The example is [step 7](growing-a-capability.md#7-shared): the fish value names
the same two files from the registry. Only one provider is selected, so the piece
lands once in each half. Two entries selecting the piece, as in the suite's
fixture [`tests/selection/shared`](https://github.com/dxcently/habit/tree/main/tests/selection/shared),
give one copy of each file.

habit reads `habit.home` only from a selected entry's top module. A file that an
entry merely imports cannot write it, so the home half has to be named in the
entry, as a path in `habit.home.imports`. Both platforms drop a second `imports`
of the same path, so the two entries' imports give one copy of each file.

The path has to stay a path. The last two rows look like the first and are not:

| written in each of the entries                          | with two entries selected                                                                                            |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `habit.home.imports = [ ./prompt-home.nix ];`          | one copy: each option declared once                                                                                  |
| `habit.home = ./prompt-home.nix;`                      | ``The option `home-manager.users.alice.example.runtime.home' in `<file>' is already declared in `<file>'.``           |
| `imports = [ (import ./prompt.nix) ];`                 | ``The option `example.runtime.system' in `<file>' is already declared in `<file>'.``                                  |

The messages name `example.runtime`, the option the suite's fixture declares, so
the same two traps with its files are the ones the suite checks
([`tests/selection/shared`](https://github.com/dxcently/habit/tree/main/tests/selection/shared)).

A bare path or an inline value is a second identity for the piece: the module
system no longer sees the copies as one file, so the options it declares are
declared twice.

## Value entries

An entry may be a module value instead of a path: an attrset, or a function of
the module's arguments. A value is for a generated family, such as one entry per
package from a list of names. A capability written by hand stays a file.

```nix
{
  catalogue = lib.genAttrs [ "fzf" "htop" ] (name: {
    programs.${name}.enable = true;
  });
}
```

A selected value is applied exactly where a file's module would be: it takes
the same `habit:<name>` key, its `habit.home` half goes to the users it reaches
by the same rules, and its conditions and priorities behave as in a file. The key
is `habit:<name>` for the module holding the system half, or for the only module a
capability has; each other provider's home-only module is `habit:<name>/<provider>`.
Two names for one value are two entries, each applied under its own key.

The read boundary is exact. Every catalogue entry is read to weak head normal
form to learn its kind (a path, an attrset or a function), so an entry that is
itself `throw` throws on read, selected or not. An attrset's attributes (`_file`,
`providers`, `config`) and a function's body are never forced unless the entry
is selected.

Where a value comes from, for errors and the inventory:

| a value is                                  | named in errors as                       | `source` in the inventory          |
| ------------------------------------------- | ---------------------------------------- | ---------------------------------- |
| an attrset with `_file`                     | its `_file`                              | its `_file`                        |
| an attrset without `_file`                  | `catalogue value '<name>'`               | `<value '<name>'>`                 |
| a function                                  | `catalogue value '<name>'`               | `<value '<name>'>`                 |
| a value provider set's chosen module value  | its `_file`, or `catalogue value '<name>.<provider>'` | its `_file`, or `<value '<name>.<provider>'>` |

A file's provider set is named by its file, whichever provider it chooses: the
inventory does not read the file to find the target. A value's provider set is
named by its chosen target. A module value target is named by its `_file`, or
else `<value '<name>.<provider>'>`. A path target is named by the set itself:
its `_file`, or else `<value '<name>'>`.

A path entry keeps the path it was written as. An attrset that coerces to a path
(an `outPath`, as a derivation or a flake input is) is a path, not a value.

An attrset with `providers` is a provider set, not a module, and a function is
always a module. `providers` is the one key that tells them apart, as it tells a
file's provider set from a file's module. NixOS, nix-darwin and Home Manager
declare no top-level `providers` option, so no platform module is read as a set.
A consumer's module that sets its own top-level `providers` option is read as a
set when `providers` is its only key, and refused, naming the capability and the
keys, when another key sits beside it. A set is read when its capability is
selected, and only its chosen target is then read
([Several providers](#several-providers)).

An entry that is none of a path, an attrset or a function is refused by the
module system, naming `habit.catalogue.<name>` and the value it got
([Errors](errors.md#selecting-capabilities)). Like every catalogue entry, it is
checked when habit reads it, so one nothing selects is not reported.

Merged registries name entries, never their values, so value entries merge and
clash like paths ([Merging registries](merging.md)).

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
