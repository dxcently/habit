# Aggregations

An aggregation is a named group of dendrites. The registry maps its name to a
directory holding its body, `default.nix`:

```nix
aggregations = {
  base = ./aggregations/base;
};
```

The body is data, read only when a host or one of its users selects the group.

## The body

```nix
# examples/full/modules/aggregations/base/default.nix
{
  description = "What every machine here carries: ssh, for the system and for each home.";

  system = {
    members = [ "ssh" ];
  };

  home = {
    members = [ "ssh" ];
  };
}
```

| field                   | means                                                                     |
| ----------------------- | ------------------------------------------------------------------------- |
| `description`           | the description of the group's `enable` option                            |
| `system` / `home`       | the half that answers when the host selects the group (its `system` half, and its `home` half for each user with a home) or a user does (its `home` half); a standalone home selects the `home` half |
| `<half>.members`        | capability names the group enables in that scope                          |
| `<half>.providers`      | `{ <member> = "<default provider>"; }` for provider-bearing members; each is also a member |
| `<half>.module`         | a module the half carries beside its members, below                       |

The two halves' `module` land where their scope's own settings do:

| half     | `module` lands                                                                               |
| -------- | -------------------------------------------------------------------------------------------- |
| `system` | in the host's evaluation, as its own module-list entry just before the host module           |
| `home`   | in the home of each user it reaches (one that selected the group, or every user with a home when the host did, less those that opted out), after the homes of that user's modules and of the matched override records, just before the user's own `home.config`; in a standalone home, as its own module-list entry just before the host module |

A selected body is validated when it is read, and each failure names the
aggregation and its file ([Errors](errors.md#aggregation-bodies)):

- a body that is not an attrset (a function written like a dendrite, a list)
  names its type;
- a field outside this table at the top (a misspelt `sytem`) names the field;
- a registry entry that is not a path (a set written in place of a file) names
  the group and its type;
- a `system` or `home` that is not an attrset names the half and its type;
- a key outside `members`, `providers` and `module` in a half (a `member`, a
  `nixos`) names the half and the key.

A body nobody selected is never read, so it is never validated either.

### One body serves both scopes

The two halves reach different evaluators, and one body serves both:

- the host selects it with `habit.aggregation.base.enable = true`. The host
  applies the `system` half, and every user with `home.enable = true` gets the
  `home` half, exactly as if each had selected the group with
  `habit.users.<name>.aggregation.base.enable = true`.
- a user selects it for herself with `habit.users.<name>.aggregation.base.enable
  = true`. Only that user gets the `home` half.
- both routes together merge: the group's membership and its `home` module apply
  once for the user.
- a user opts out of a group the host sent with
  `habit.users.<name>.aggregation.base.enable = false`. That withholds the
  group's `home` half for that user alone; the `system` half is the host's and
  stays ([Opting out](host.md#opting-out)).

A standalone home has no users. It selects with
`habit.aggregation.base.enable = true` too, and gets the `home` half, so the
group's `system` half is not read there. `examples/full`'s `hosts/alice` does
this.

A host's group sends its home members to users, and their system halves are
the host's. Whenever the host selects the group, each home member's system half
applies on the host with its host-level `system` (default `true`), whatever the
users do, including when there are no users with a home. A user's opt-out
withholds only that user's home half ([Opting out](host.md#opting-out)). A
member's provider for its system half is the provider the users' home claims
name, or the group's default when none of them is active; users who choose
different providers for one member are refused, as they are for user
selections ([Errors](errors.md#selecting-capabilities)).

## What every host carries

The constructor has no slot for what every host carries. A host gets it by
selecting an aggregation of its own, and can deselect a member as in any other
group. A module that must reach a host even when it selects nothing goes in
`extraModules`.

## Membership is mkDefault

For each member of a selected half, the group writes:

```nix
habit.dendrites.<member>.enable = mkDefault true;
habit.dendrites.<member>.provider = mkDefault <the group's provider option>;   # provider-bearing members
```

Everything about membership follows from that priority.

| situation                                              | outcome                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| host sets `habit.dendrites.tmux.enable = false`        | `false` (priority 100) beats the group's `true` (1000): tmux is never imported |
| a layer above sets `habit.dendrites.tmux.enable = mkForce true` | back on: `mkForce` (50) beats the host's `false`   |
| two selected groups name the same member, same terms   | they merge into one selection; the module is imported once    |
| two selected groups choose different providers for it  | error: `habit.dendrites.<member>.provider` has conflicting definition values |
| host sets `habit.dendrites.shell.provider = "fish"`    | the host's choice beats the group's default                   |

A group writes only `enable` and `provider`, so the rest of a member's selection
is the host's: `habit.dendrites.<member>.system = false` keeps the member and
asks for its home half alone ([Dendrites](dendrites.md#halves-and-scopes)).

`examples/full`'s `dev` group has `tmux` as a member, and its desk switches that
member off:

```nix
# examples/full/hosts/desk/default.nix
{
  habit.aggregation.base.enable = true;
  habit.aggregation.terminal.enable = true;
  habit.aggregation.dev.enable = true;
  habit.dendrites.tmux.enable = false;

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

`desk` gets `ssh` and not `tmux`. The suite replaces `tmux`'s file with one that
throws on import and the host still builds, then sets
`habit.dendrites.tmux.enable = lib.mkForce true` on top, from a
`selectionModules` module, and the throwing file is reached. Two groups that
disagree on a provider collide instead of letting import order pick a winner.

## Choosing a provider

A provider-bearing member gets a selector under the group that owns it, in
that scope: `habit.aggregation.<group>.<member>.provider`. Its default is the
body's `providers.<member>`. In [`terminal`](growing-a-capability.md#5-terminal)
the member `terminal` has the default `kitty`, so a host that wants `foot` writes
`habit.aggregation.terminal.terminal.provider = "foot";`. A single-implementation
member gets no selector at all.

The selector is typed only in the select step, once the body is read
([The two passes](two-passes.md#selection-gate-then-select)). Before that it is
accepted untyped, so a selector the group does not own
(`habit.aggregation.terminal.compositor.provider`) fails in the select step as an
option that does not exist.

## A group cannot select a group

The body is data with no `aggregation` field, so the gate step's answer is
final and no recursion is needed to settle it.

## Discovering groups

The registry's `aggregations` is plain data, so a consumer may write it by
hand or generate it from a directory without reading any body. The fixture
registry does the latter with `builtins.readDir`, in
`tests/selection/aggregations/default.nix`.
