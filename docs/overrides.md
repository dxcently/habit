# Override records

Some fixes belong to a capability, not to a host: a package whose upstream
build broke, a setting every machine running the thing wants. An override
record names the dendrites it is about, and the constructor applies it to the
hosts that selected one of them. A record selects nothing: one whose targets
nobody chose simply never applies.

The registry's optional `overrides` maps record names to files:

```nix
overrides = {
  broken-upstream = ./fixes/broken-upstream.nix;
};
```

## The record

```nix
{
  dendrites = [ "notifications" ];              # required: catalogue names
  hosts = [ "desk" ];                           # optional: confine to these hosts
  overlay = final: prev: { … };                 # optional
  system = { … };                               # optional
  home = { … };                                 # optional
}
```

| field         | required | means                                                               |
| ------------- | -------- | ------------------------------------------------------------------- |
| `dendrites`   | yes      | a non-empty list of catalogue names the record is about             |
| `hosts`       | no       | the host names it is confined to; each must be in `knownHosts`      |
| `overlay`     | one of these three | a package overlay for the host's package set              |
| `system`      | one of these three | a module for the host's evaluation                        |
| `home`        | one of these three | a Home Manager module                                     |

`system` and `home` are the two halves a dendrite has, so a record carries the
same pair. A field that is silently dropped is worse than one that does not
exist, so a field outside the five is an error.

## Matching

```
record ──► hosts admits this host? ──no──► not applied
                │ yes
                ▼
           a target selected here (system, or by any user)? ──no──► not applied
                │ yes
                ▼
           overlay applies to the host, once
           system applies to the host, once, if a selection of a target has system = true
           home rides the users the target's home half reaches
```

- A record matches the **host** when its `hosts` admits the host and any target
  was selected here, for the system or by one of its users. A capability only a
  user selected still matches the host: with `useGlobalPkgs` a user's home
  draws from the host's package set, so there is no separate home one to fix.
- Its `overlay` applies **once**, however many of its targets were selected.
- Its `system` module applies **once** too, and follows its target's system
  half: only when some selection of a target has `system = true`
  ([Dendrites](dendrites.md#halves-and-scopes)). A target selected only with
  `system = false` still draws the `overlay` and the `home` module, since the
  home draws from the host's package set, but not the `system` module.
- Its `home` module rides exactly the users the target's home half reaches:
  every user with Home Manager when the host selected the target, the selecting
  user alone when a user did, so the fix travels with the thing it fixes.
- A standalone home has no users and no system half: a record that matches its
  own selection applies its `overlay` and its `home` module to the home, and its
  `system` module to nothing.
- Records are taken in name order, so the result does not depend on the
  filesystem. Overlays compose the ordinary Nix way, each seeing the one before
  as `prev`; there is no overlap detection beyond that.
- A record's overlays are applied after the selected modules' and before the
  caller's. On an attribute they share, the record's wins over a module's and
  the caller's wins over the record's, so the consumer's own
  overlays keep the last word (`overlayOrder`, `recordOverlayBeatsDendrite`,
  `callerOverlayBeatsRecord`). The host's own overlays are applied first and
  lose to all of these ([the module list](constructor.md#the-module-list)).

The inventory lists which records matched (`inventory.overrides`).

## Validation

A record is validated on every host, matched or not, so a typo cannot hide on
the machines it would not have applied to. Each failure names the record and
its file:

| fault                                      | message contains                                               |
| ------------------------------------------ | -------------------------------------------------------------- |
| a field outside the five                   | `has unknown field(s): …; a record takes only dendrites, hosts, overlay, system, home` |
| no `dendrites`, or an empty list           | `names no dendrites; a record must say which capabilities it is about` |
| a target not in the catalogue              | `targets unknown dendrite(s): …; every target must be a catalogue name` |
| a host not in `knownHosts`                 | `is confined to unknown host(s): …`                            |
| none of `overlay`, `system`, `home`        | `carries nothing to apply; give it an overlay, a system module or a home module` |

A consumer building several hosts passes every host name as `knownHosts` to
each, or a record confined to another host fails on this one
([The constructor](constructor.md#arguments)).

## The evaluation boundary

This boundary is weaker than selection's, and it is stated exactly:

- Every host imports every record file, because matching is reading. The
  record's attrset and its `dendrites` and `hosts` lists are evaluated on every
  host.
- `overlay` is a function, and `system` and `home` are best written as
  functions (`{ pkgs, ... }: { … }`). An unmatched record's functions are never
  called.

Keep imports and package computation inside those functions. Metadata that
computes (a `dendrites` list built by importing something) defeats the
boundary. The suite proves only the function bodies:
`tests/selection/overrides/tripwire.nix`
throws from its overlay and its `system` module, and resolving a host that does
not select its target succeeds.
