# Dendrites

A dendrite is one capability: a name in the registry's `catalogue` and the file
or directory that answers it.

```nix
catalogue = {
  ssh = ./dendrites/ssh;                       # a directory with default.nix
  notifications = ./dendrites/notifications;
  obsidian = ./caps/obsidian.nix;              # or a file
};
```

The catalogue holds names and paths only. An entry is `import`ed in the
platform pass, and only when some scope enabled it.

## A lane record

A single-implementation dendrite evaluates to a lane record: one attribute per
evaluator it supports, each a module for that evaluator.

| lane          | consumed by                                          |
| ------------- | ---------------------------------------------------- |
| `nixos`       | the system scope: imported into the host's module list |
| `homeManager` | a user scope: imported into that user's Home Manager configuration |
| `darwin`      | nothing; accepted as a name a dendrite may carry, never imported |

A dendrite exposes the lanes it supports and no empty stand-ins for the rest.
A lane's value is any module: an attrset, a function, or a path.

```nix
# examples/minimal/dendrites/ssh/default.nix
{
  nixos = {
    services.openssh.enable = true;
  };
}
```

There is no darwin constructor, so a `darwin` lane is listed among the lanes a
dendrite supports (in error messages) and never read.

## Several providers

A capability with more than one implementation is a provider set. Each
provider file is a lane record of its own.

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
# examples/workstation/dendrites/notifications/dunst.nix
{
  homeManager = {
    services.dunst.enable = true;
  };
}
```

```nix
# examples/workstation/dendrites/notifications/mako.nix
{
  homeManager = {
    services.mako.enable = true;
  };
}
```

The entry file is read when the capability is enabled; of its provider files,
only the chosen one is ever imported. A provider is chosen per scope, so one
user can run `mako` while another runs `dunst` on the same host.

| selection                                     | result                                                     |
| --------------------------------------------- | ---------------------------------------------------------- |
| enabled, `provider = "dunst"`                 | `dunst.nix` is imported; `mako.nix` is never read          |
| enabled, no provider                          | error naming the available providers                       |
| enabled, `provider = "nope"`                  | error naming the available providers                       |
| single implementation, any `provider`         | error: it takes no provider                                |

A provider is chosen with `dendrites.<name>.provider`, or under the
aggregation that groups it ([Aggregations](aggregations.md#choosing-a-provider)).

## Lanes and scopes

Selecting a capability in a scope asks for that scope's lane. Asking for a lane
the dendrite (or its chosen provider) does not expose is an error naming the
lanes it does, not a silently skipped import:

```
dendrite 'notifications/mako' is selected for the system but exposes no nixos lane; it supports: homeManager
```

A system selection asks for `nixos`; a user's selection asks for
`homeManager`. Selecting a capability for the system does not select it for
any user, and the other way round.

## The inventory names the answer

The inventory records, per selected capability, its provider and `source`: the
catalogue path that answered. See
[The constructor](constructor.md#the-inventory).
