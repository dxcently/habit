# The host module

The host is one module. The platform (NixOS, nix-darwin or Home Manager)
evaluates it whole, like any module, and habit reads the keys it wrote under
`habit` to decide what the host is made of. It is given to the constructor as
`host`: a path, or a module value.

```nix
# examples/workstation/hosts/desk.nix
{
  habit.aggregation.desktop.enable = true;
  habit.dendrites.printing.enable = false;

  habit.users.alice = {
    definition = ../users/alice.nix;
    home.enable = true;
    aggregation.desktop = {
      enable = true;
      notifications.provider = "dunst";
    };
  };

  networking.hostName = "desk";
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.isContainer = true;
  system.stateVersion = "26.11";
}
```

Everything under `habit` selects; everything else is ordinary platform
configuration, evaluated by the platform and by nothing before it. The host
module is the last entry of the module list
([The constructor](constructor.md#the-module-list)), after the selected groups'
`system.module`s.

```
                ┌─► scan: the `habit.*` keys only ──► resolved selection ──► module list
host module ────┤        (pkgs, config poisoned; imports dropped;
                │         every other key left unforced)
                └─► the platform evaluation: the whole module, as the last entry
```

## Keys

| key                                              | type                 | default | means                                                    |
| ------------------------------------------------ | -------------------- | ------- | -------------------------------------------------------- |
| `habit.dendrites.<name>.enable`                  | bool                 | `false` | select a capability for the system                       |
| `habit.dendrites.<name>.provider`                | null or string       | `null`  | which provider answers it for the system                 |
| `habit.dendrites.<name>.system`                  | bool                 | `true`  | `false` asks for the home half alone ([Dendrites](dendrites.md#halves-and-scopes)); only its home half then applies, to every user with `home.enable`, unless another selection has `system = true` |
| `habit.aggregation.<group>.enable`               | bool                 | `false` | select a group's `system` half                           |
| `habit.aggregation.<group>.<member>.provider`    | null or string       | the body's | choose a provider for a provider-bearing member       |
| `habit.users.<user>`                             | submodule            | `{ }`   | a user attached to this host (below)                     |
| `habit.catalogue`                                | attrs of path, read-only | the registry's | the catalogue, read back by the platform pass   |

`<name>` and `<group>` are generated from the registry: a name the registry
does not have fails as an option that does not exist, naming the file that set
it. Selecting is explicit: setting a capability's own options never selects it.

`habit.dendrites`, `habit.aggregation`, `habit.users`, `habit.selected` and
`habit.home` are habit's own names. A `selectionModules` module may add keys
beside them and may not declare one of them
([The constructor](constructor.md#the-two-hooks)).

## The scan

Selection has to read the host before any platform evaluation exists, and the
host is also a platform module. The scan reads the part of it that selection
needs and nothing else.

For the selection pass habit applies the host module to the caller's
`specialArgs` (with `system` and `host`), with four arguments replaced by values
that throw, and drops its `imports`:

| argument    | in the scan                                                                  |
| ----------- | ---------------------------------------------------------------------------- |
| `config`, `pkgs`, `options`, `osConfig` | throw, naming the host file and the argument     |
| `lib`       | the `lib` habit was applied to, unless `specialArgs` holds its own           |
| anything else | the caller's `specialArgs`; one the host takes and none provides throws where it is read, naming the host file and the argument |
| `imports`   | not followed, and not evaluated                                              |

What is left is read through one typed `habit` option; every other key goes to
a freeform sink that is never forced. So a host may set `networking.hostName =
config.something`, `services.foo.package = pkgs.hello` or guard a module behind
`mkIf config.x`, and none of it runs during selection.

Three consequences, each with a test:

- **Selection cannot depend on the platform.** A `habit` key that needs `config`
  or `pkgs` is refused, naming the host file and the argument, never skipped:

  ```
  habit: host hosts/box.nix reads `config` while selection is being read; selection may not depend on platform configuration
  ```

  This holds for `habit.dendrites.x.enable = mkIf config.y true`, for
  `habit = mkIf …`, for `config = mkIf … { habit… }` and for a whole host that
  is a `mkIf`. A condition over platform configuration that guards no `habit`
  key is never forced, and nothing is raised for it. A host written
  `args: { … }` is poisoned the same way as one with named formals.
- **A typo is loud.** `habit` is one typed option, so `habit.dendrtes` is an
  option that does not exist, naming the host file, with the nearest names
  suggested, and never reaches the sink.
- **Arguments the scan cannot make come from the caller.** A host that reads
  an input or a username in a `habit` key needs it in `specialArgs`; without it:

  ```
  habit: host hosts/box.nix takes argument(s) username which the scan does not provide; pass them in specialArgs
  ```

  An argument used only under `imports`, as `modulesPath` usually is, is never
  read, so the host scans without it.

### Imports are not scanned

A file the host `imports` is never read by the scan, so a selection written in
it would be absorbed and select nothing. The platform evaluates the whole host,
so the platform evaluation declares the same `habit.*` keys, inert, and fails every key
the scan did not see: any key written by a file other than the host's, whatever
it holds, and any key written inline in the host's own `imports`, which shares
the host's file, whose value selection does not hold. An unwritten key is `null`
there and draws nothing:

```
`habit.dendrites.kitty.enable` is set in hosts/shared.nix but the host scan never saw it (scans do not follow `imports`)
```

A `habit.users.<user>.home.config` written inline in the host's own `imports`
is the one key not caught: it has the host's file and no value to compare.
This is the only catch for a selection in an `imports` list guarded by platform
configuration. It covers every `habit` key: `habit.dendrites`,
`habit.aggregation` and `habit.users` (including `home.config`), and the keys a
`selectionModules` module declares. A key an `extraModules` entry writes is
refused the same way. The assertion is an entry of `config.assertions`, which
NixOS, nix-darwin and Home Manager each declare and fail the build on; an
evaluation of the module list by bare `lib.evalModules` declares `assertions`
itself.

## Users

Each `habit.users.<user>` is a scope of its own.

| field                                        | type            | default | means                                                       |
| -------------------------------------------- | --------------- | ------- | ----------------------------------------------------------- |
| `definition`                                 | path            | none    | the user's module: its own settings are the account, its `habit.home` is the user's home |
| `home.enable`                                | bool            | `false` | give this user a Home Manager configuration; off imports no Home Manager for them |
| `home.config`                                | deferred module | `{ }`   | extra home settings, evaluated only in the user's Home Manager configuration |
| `dendrites.<name>.enable` / `.provider` / `.system` | as above |         | select a capability for this user's home; `system = false` asks for its home half alone |
| `aggregation.<group>.enable` / `.<member>.provider` | as above |         | select a group's `home` half for this user                  |

```nix
# examples/workstation/users/alice.nix
{
  users.users.alice.isNormalUser = true;

  habit.home = {
    home.stateVersion = "26.11";
  };
}
```

The user's module is an ordinary module, wrapped like a dendrite
([Dendrites](dendrites.md#a-plain-module)): its own settings are the account,
applied in the host's evaluation for every user on the host, Home Manager or
not; its `habit.home` goes to that user alone, and only when `home.enable =
true`. Like a dendrite, it selects nothing: a `habit.dendrites` key in it is
refused by name.

### What a user's home is made of

For each user with `home.enable = true`, in this order. The first two are
separate definitions of `home-manager.users.<user>`, merged in module-list
order ([The constructor](constructor.md#the-module-list)); the rest are the
imports of the wiring's own definition, which comes after them:

1. the user module's `habit.home`
2. the home half of every capability the host selected and of every capability
   this user selected, in catalogue order
3. `habit.selected`, this user's own scope ([Dendrites](dendrites.md#reading-the-selection))
4. the `home` module of every override record the user's own selection
   matched
5. the `home.module` of every group the user selected, then `home.config`

### Home Manager wiring

The constructor imports `homeManagerModule` only when at least one user has
`home.enable = true`; a host with no home user never imports it. When it
does, it sets:

| option                           | value                                          |
| -------------------------------- | ---------------------------------------------- |
| `home-manager.useUserPackages`   | `true`                                         |
| `home-manager.useGlobalPkgs`     | `true`: homes draw from the host's package set |
| `home-manager.backupFileExtension` | `"backup"`                                   |
| `home-manager.extraSpecialArgs`  | the constructor's `specialArgs` (with `system` and `host`) |
| `home-manager.users.<user>`      | the wiring's imports above, beside the halves routed to the user |

A user who selects home capabilities with `home.enable = false` is an error,
not a quiet no-op:

```
host 'desk': user 'alice' has home.enable = false but selects home dendrites: notifications
```

Home Manager here is the NixOS module; on darwin it is its darwin module, and
a standalone home has no users at all (below).

## A darwin host

A darwin host is a nix-darwin module with the same `habit.*` keys and the same
users, and `mkDarwinHost` takes Home Manager's `darwinModules.home-manager` as
`homeManagerModule`. It takes `system = "aarch64-darwin"` too: `system` defaults
to `"x86_64-linux"` and becomes the `system` module argument. Home Manager takes
a user's home directory from `users.users.<user>.home` there, so a user module
on darwin sets it. habit has no declaration for whether a module supports darwin;
a module that sets an option nix-darwin does not have fails as the module
system's own error ([Dendrites](dendrites.md#darwin)).

The suite evaluates a darwin host for `aarch64-darwin` from Linux against the
real nix-darwin and Home Manager, down to `system.build.toplevel.drvPath` (the
overview's Tests section). It builds nothing on a Mac.

## A standalone home

A standalone home is a Home Manager configuration with no system around it, and
its host module is the home's own module:

```nix
# examples/home/hosts/alice.nix
{
  habit.dendrites.ssh.enable = true;

  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "26.11";
}
```

The scan reads it as it reads any host. What a home accepts under `habit`:

| key                                              | in a home                                                 |
| ------------------------------------------------ | --------------------------------------------------------- |
| `habit.dendrites.<name>.enable` / `.provider`    | select a capability for the home                          |
| `habit.aggregation.<group>.enable` / `.<member>.provider` | select a group's `home` half; its `system` half is not read |
| a `selectionModules` key                         | as for any host; the module's `scope` argument is `"home"` |
| `habit.users`                                    | refused                                                   |

A home is one user's configuration, so there is nothing to attach users to; the
module that would have been `habit.users.<user>.home.config` is the host module
itself. Setting `habit.users` fails naming the file:

```
habit: host hosts/alice.nix sets `habit.users`; a standalone home has no users, the host module is the home itself
```

What a selected capability gives the home:

- its system half is dropped, `imports` with it, so a module whose system half
  sets an option Home Manager does not have still evaluates;
- its home half is imported into the home, where Home Manager itself reads it
  as it reads the rest of the module list;
- `habit.selected` is the home's own selection;
- a matched override record contributes its `overlay` and its `home` module; its
  `system` module is dropped with the rest of the system half.

`homeManagerModule` is refused: Home Manager is the evaluator, and there is
nothing to import.
