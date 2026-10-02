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
    definition = ./users/khoa.nix;                          # { nixos; homeManager? }
    homeManager.enable = true;
    dendrites.notifications = { enable = true; provider = "mako"; };
    homeManager.config = { … };                             # extra home settings
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
([The constructor](constructor.md#the-module-list)), merged with the `nixos`
half of every selected group.

## Users

Each `users.<user>` is a scope of its own.

| field                                        | type            | default | means                                                       |
| -------------------------------------------- | --------------- | ------- | ----------------------------------------------------------- |
| `definition`                                 | path            | none    | the shared user definition: `{ nixos; homeManager?; }`      |
| `homeManager.enable`                         | bool            | `false` | evaluate this user's home lane; off imports no Home Manager for them |
| `homeManager.config`                         | deferred module | `{ }`   | extra home settings, evaluated only in the home lane        |
| `dendrites.<name>.enable` / `.provider`      | as above        |         | select a capability for this user's home                    |
| `aggregation.<group>.enable` / `.<member>.provider` | as above |         | select a group's `home` half for this user                  |

```nix
# examples/workstation/users/alice.nix
{
  nixos = {
    users.users.alice.isNormalUser = true;
  };
  homeManager = {
    home.stateVersion = "26.11";
  };
}
```

The definition's `nixos` lane is the account: it is imported for every user on
the host, Home Manager or not. A definition without one is an error, since the
user would have no account. Its optional `homeManager` lane opens that user's
home configuration.

### What a user's home is made of

For each user with `homeManager.enable = true`, in this order:

1. the definition's `homeManager` lane, if it has one
2. the `homeManager` lane of every capability the user selected
3. the `homeManager` module of every override record the user's own selection
   matched
4. `homeManager.config`, merged with the `home.homeManager` half of every group
   the user selected

### Home Manager wiring

The constructor imports `homeManagerModule` only when at least one user has
`homeManager.enable = true`; a host with no home user never imports it. When it
does, it sets:

| option                           | value                                          |
| -------------------------------- | ---------------------------------------------- |
| `home-manager.useUserPackages`   | `true`                                         |
| `home-manager.useGlobalPkgs`     | `true`: home lanes draw from the host's package set |
| `home-manager.backupFileExtension` | `"backup"`                                   |
| `home-manager.extraSpecialArgs`  | the constructor's `specialArgs` (with `system` and `host`) |
| `home-manager.users.<user>`      | the list above                                 |

A user who selects home capabilities with `homeManager.enable = false` is an
error, not a quiet no-op:

```
host 'desk': user 'alice' has homeManager.enable = false but selects home dendrites: notifications
```

Home Manager here is the NixOS module. There is no standalone
`homeConfigurations` output.
