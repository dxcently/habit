# The host record

The host record is what one host selects. It is one or more modules
(`hostModules`) evaluated by the selection pass, never by NixOS.

```nix
{
  aggregation.workstation.enable = true;                    # groups
  aggregation.workstation.notifications.provider = "dunst"; # a provider, under its group
  dendrites.obsidian.enable = true;                         # lone capabilities
  dendrites.kitty.enable = false;                           # a group member, switched off
  users.khoa = {
    definition = ./users/khoa.nix;                          # a plain module: the account, and habit.home
    home.enable = true;
    dendrites.notifications = { enable = true; provider = "mako"; };
    home.config = { … };                                    # extra home settings
  };
  nixos = { pkgs, ... }: { … };                             # this machine, deferred
}
```

## Fields

| field                                        | type                 | default | means                                                    |
| -------------------------------------------- | -------------------- | ------- | -------------------------------------------------------- |
| `dendrites.<name>.enable`                    | bool                 | `false` | select a capability for the system                       |
| `dendrites.<name>.provider`                  | null or string       | `null`  | which provider answers it for the system                 |
| `aggregation.<group>.enable`                 | bool                 | `false` | select a group's `system` half                           |
| `aggregation.<group>.<member>.provider`      | null or string       | the body's | choose a provider for a provider-bearing member       |
| `users.<user>`                               | submodule            | `{ }`   | a user attached to this host (below)                     |
| `nixos`                                      | deferred module      | `{ }`   | this host's own NixOS settings and hardware              |
| `catalogue`                                  | attrs of path, read-only | the registry's | the catalogue, read back by the platform pass   |

`<name>` and `<group>` are generated from the registry: a name the registry
does not have fails as an option that does not exist, naming the file that
set it when the host module is a path.

The selection modules receive `lib` and `scope` (`"system"` at the top,
`"home"` inside a user) as module arguments. They do not receive `pkgs` or any
NixOS `config`: [the selection pass](two-passes.md) has neither.

`nixos` is a `deferredModule`: anything may go in it, and nothing in it can
influence selection. It lands last in the module list
([The constructor](constructor.md#the-module-list)), merged with the
`system.module` of every selected group.

## Users

Each `users.<user>` is a scope of its own.

| field                                        | type            | default | means                                                       |
| -------------------------------------------- | --------------- | ------- | ----------------------------------------------------------- |
| `definition`                                 | path            | none    | the user's module: its own settings are the account, its `habit.home` is the user's home |
| `home.enable`                                | bool            | `false` | give this user a Home Manager configuration; off imports no Home Manager for them |
| `home.config`                                | deferred module | `{ }`   | extra home settings, evaluated only in the user's Home Manager configuration |
| `dendrites.<name>.enable` / `.provider`      | as above        |         | select a capability for this user's home                    |
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
true`.

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
5. `home.config`, merged with the `home.module` of every group the user
   selected

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

Home Manager here is the NixOS module. There is no standalone
`homeConfigurations` output.
