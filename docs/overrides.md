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
  nixos = { … };                                # optional
  homeManager = { … };                          # optional
}
```

| field         | required | means                                                               |
| ------------- | -------- | ------------------------------------------------------------------- |
| `dendrites`   | yes      | a non-empty list of catalogue names the record is about             |
| `hosts`       | no       | the host names it is confined to; each must be in `knownHosts`      |
| `overlay`     | one of these three | a package overlay for the host's package set              |
| `nixos`       | one of these three | a NixOS module                                            |
| `homeManager` | one of these three | a Home Manager module                                     |

There is no `darwin` field: there is no darwin constructor to apply it, and a
field that is silently dropped is worse than one that does not exist.

## Matching

```
record ──► hosts admits this host? ──no──► not applied
                │ yes
                ▼
           a target selected here (system, or by any user)? ──no──► not applied
                │ yes
                ▼
           overlay + nixos apply to the host, once
           homeManager rides each user whose OWN selection hit a target
```

- A record matches the **host** when its `hosts` admits the host and any target
  was selected here, for the system or by one of its users. A capability only a
  user selected still matches the host: with `useGlobalPkgs` the home lane
  draws from the host's package set, so there is no separate home one to fix.
- Its `overlay` and `nixos` module apply **once**, however many of its targets
  were selected.
- Its `homeManager` module rides only the users whose own home selection hit
  a target. Every user on a matched host would put one person's fix in
  everyone else's home.
- Records are taken in name order, so the result does not depend on the
  filesystem. Overlays compose the ordinary Nix way, each seeing the one before
  as `prev`; there is no overlap detection beyond that.

The inventory lists which records matched (`inventory.overrides`).

## Validation

A record is validated on every host, matched or not, so a typo cannot hide on
the machines it would not have applied to. Each failure names the record and
its file:

| fault                                      | message contains                                               |
| ------------------------------------------ | -------------------------------------------------------------- |
| a field outside the five                   | `has unknown field(s): …; a record takes only dendrites, hosts, overlay, nixos, homeManager` |
| no `dendrites`, or an empty list           | `names no dendrites; a record must say which capabilities it is about` |
| a target not in the catalogue              | `targets unknown dendrite(s): …; every target must be a catalogue name` |
| a host not in `knownHosts`                 | `is confined to unknown host(s): …`                            |
| none of `overlay`, `nixos`, `homeManager`  | `carries nothing to apply; give it an overlay, a nixos module or a homeManager module` |

A consumer building several hosts passes every host name as `knownHosts` to
each, or a record confined to another host fails on this one
([The constructor](constructor.md#arguments)).

## The evaluation boundary

This boundary is weaker than selection's, and it is stated exactly:

- Every host imports every record file, because matching is reading. The
  record's attrset and its `dendrites` and `hosts` lists are evaluated on every
  host.
- `overlay` is a function, and `nixos` and `homeManager` are best written as
  functions (`{ pkgs, ... }: { … }`). An unmatched record's functions are never
  called.

Keep imports and package computation inside those functions. Metadata that
computes (a `dendrites` list built by importing something) defeats the
boundary. The suite proves only the function bodies:
`tests/selection/overrides/tripwire.nix`
throws from its overlay and its `nixos` module, and resolving a host that does
not select its target succeeds.
