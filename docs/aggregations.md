# Aggregations

An aggregation is a named group of dendrites. The registry maps its name to a
directory holding its body, `default.nix`:

```nix
aggregations = {
  desktop = ./aggregations/desktop;
};
```

The body is data, read only when a host or one of its users selects the group.

## The body

```nix
# examples/workstation/aggregations/desktop/default.nix
{
  description = "A machine someone sits at.";

  system = {
    members = [
      "bluetooth"
      "printing"
    ];
    nixos = {
      services.xserver.xkb.layout = "de";
    };
  };

  home = {
    providers.notifications = "mako";
  };
}
```

| field                   | means                                                                     |
| ----------------------- | ------------------------------------------------------------------------- |
| `description`           | the description of the group's `enable` option                            |
| `system` / `home`       | the half that answers when the host / a user selects the group            |
| `<half>.members`        | capability names the group enables in that scope                          |
| `<half>.providers`      | `{ <member> = "<default provider>"; }` for provider-bearing members; each is also a member |
| `system.nixos`          | NixOS settings that ride the platform pass with the host's own `nixos`    |
| `home.homeManager`      | Home Manager settings that ride each selecting user's home lane           |

A `nixos` in the home half, or a `homeManager` in the system half, fails as an
option that does not exist.

A selected body is validated when it is read, and each failure names the
aggregation and its file ([Errors](errors.md#aggregation-bodies)):

- a body that is not an attrset (a function written like a dendrite, a list)
  names its type;
- a field outside this table at the top (a misspelt `sytem`) names the field;
- a `system` or `home` that is not an attrset names the half and its type;
- a key outside `members`, `providers`, `nixos` and `homeManager` in a half (a
  `member`, a `nixso`) names the half and the key.

A body nobody selected is never read, so it is never validated either.

One body serves both scopes. The host selects it with
`aggregation.desktop.enable = true` and gets the `system` half; a user selects
it with `users.<name>.aggregation.desktop.enable = true` and gets the `home`
half. The two halves reach different evaluators.

## Membership is mkDefault

For each member of a selected half, the group writes:

```nix
dendrites.<member>.enable = mkDefault true;
dendrites.<member>.provider = mkDefault <the group's provider option>;   # provider-bearing members
```

Everything about membership follows from that priority.

| situation                                              | outcome                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------- |
| host sets `dendrites.printing.enable = false`          | `false` (priority 100) beats the group's `true` (1000): printing is never imported |
| a layer above sets `dendrites.printing.enable = mkForce true` | back on: `mkForce` (50) beats the host's `false`        |
| two selected groups name the same member, same terms   | they merge into one selection; the lane is imported once      |
| two selected groups choose different providers for it  | error: `dendrites.<member>.provider` has conflicting definition values |
| host sets `dendrites.notifications.provider = "x"`     | the host's choice beats the group's default                   |

The workstation example switches a member off:

```nix
# examples/workstation/hosts/desk.nix
{
  aggregation.desktop.enable = true;
  dendrites.printing.enable = false;

  users.alice = {
    definition = ../users/alice.nix;
    homeManager.enable = true;
    aggregation.desktop = {
      enable = true;
      notifications.provider = "dunst";
    };
  };

  nixos = {
    networking.hostName = "desk";
  };
}
```

`desk` gets `bluetooth` and not `printing`; the suite replaces `printing`'s
body with one that throws on import and the host still builds, then sets
`dendrites.printing.enable = lib.mkForce true` on top and the throwing body is
reached. Two groups that disagree on a provider collide instead of letting
import order pick a winner.

## Choosing a provider

A provider-bearing member gets a selector under the group that owns it, in
that scope: `aggregation.<group>.<member>.provider`. Its default is the
body's `providers.<member>`. In `desk.nix` above, alice takes `desktop`'s home
half and picks `dunst` over the body's `mako`. A single-implementation member
gets no selector at all.

The selector is typed only in the select step, once the body is read
([The two passes](two-passes.md#selection-gate-then-select)). Before that it is
accepted untyped, so a selector the group does not own
(`aggregation.desktop.compositor.provider`) fails in the select step as an
option that does not exist.

## A group cannot select a group

The body is data with no `aggregation` field, so the gate step's answer is
final and no recursion is needed to settle it.

## Discovering groups

The registry's `aggregations` is plain data, so a consumer may write it by
hand or generate it from a directory without reading any body. The fixture
registry does the latter with `builtins.readDir`, in
`tests/selection/aggregations/default.nix`.
