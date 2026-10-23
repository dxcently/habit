# Registry rules

A capability sometimes needs another one, or belongs on some hosts only, or
should reach only so many homes. A rule states that about a catalogue name. It
refuses; it never selects. A rule that holds is silent. One that does not hold
fails the build, naming the rule and what it broke.

The registry's optional `rules` maps catalogue names to rules:

```nix
rules = {
  tailscale.needs = [ "sops" ];        # selected => sops is selected too
  nvidia.hosts = [ "yomi-strix" ];     # selected only on these hosts
  syncthing.homes = 1;                 # reaches at most one user's home per host
};
```

Each rule is keyed by a catalogue name and holds plain data. Nothing in it is a
function, a path or a package, and no catalogue entry is imported to read it.

## The three fields

| field   | type                 | means                                                              |
| ------- | -------------------- | ------------------------------------------------------------------ |
| `needs` | list of names        | each named entry must be selected wherever this one is            |
| `hosts` | list of host names   | the entry may be selected on these hosts only                     |
| `homes` | positive integer     | on one host, the entry's home half reaches at most this many users |

A rule takes only these three. A rule with none of them says nothing, and is
harmless, but a misspelt field is an error, not a silent no-op.

## Needs

`needs` reads differently for the system and for a user's home.

- **The system.** When the host selects the entry for the system, each need
  must be selected for the system too.
- **A home.** When the entry reaches a user's home, each need must reach that
  user's home, or be selected for the host's system. A home may lean on the
  system, so the host selecting `sops` satisfies every user's `tailscale`. A
  user who switched `sops` off still leans on it: the host's selection provides
  `sops` to the system, and the user's switch removes only their own home half
  of it.

```
host selects tailscale ── for the system ── sops selected for the system?
                                             │ no
                                             ▼
                                     refused, host scope

alice reaches tailscale's home
  │
  ├── alice's home reaches sops ───────────── ok
  ├── host selects sops (system) ───────────── ok (leans on the system)
  └── otherwise ───────────────────────────── refused, user scope
```

[`examples/full`](https://github.com/dxcently/habit/tree/main/examples/full)
has `terminal.needs = [ "shell" ]`: its `desk` has bob switch `shell` off for
his home, and his `terminal` still leans on the system's shell.

Every unmet need is reported in one error, so a host sees all of them at once.

## Hosts

`hosts` refuses a selection of the entry on a host it does not list. A
selection counts wherever it comes from: a host's own, a group the host
selected, or a user's. The refusal names how the entry was selected:

- `directly`, when the host's own `habit.dendrites.<name>.enable` wrote it;
- `via aggregation '<g>'`, when a group the host selected names it;
- `by user '<u>'`, when a user selected it.

A rule on an entry with several providers applies to the entry whatever
provider answers it. There are no provider-level rules.

A standalone home ([A standalone home](host.md#a-standalone-home)) is named by
its builder's `hostName`, so `hosts` lists that name. A darwin host is named the
same way, by the `hostName` given to `mkDarwinHost`.

## Homes

`homes` counts the users whose home the entry's home half reaches on one host.
Those users are the ones with a home that either select the entry or are
reached by the host's own selection
([Opting out](host.md#opting-out)). Above the limit, the refusal names the users
and the fix: switch all but the limit off, with
`habit.users.<u>.dendrites.<name>.enable = false`.

A standalone home has no users and counts as one, so `homes` never refuses one.

## Validation

A rule is checked on every host, matched or not. A typo fails on the machines
it would not have applied to, and so the check does not wait on a selection.
Each message names the rule, and the registry it came from when the registries
are merged ([Merging registries](merging.md)).

| fault                                   | message contains                                                               |
| --------------------------------------- | ------------------------------------------------------------------------------ |
| a field outside the three               | `has unknown field(s): …; a rule takes only needs, hosts, homes`               |
| a name not in the catalogue             | `names no catalogue entry; a rule is keyed by a catalogue name`                |
| a rule that is not an attrset           | `is a <type>, not an attrset; a rule takes only needs, hosts, homes`           |
| `needs` not a list                      | `` `needs` is a <type>, not a list of catalogue names ``                       |
| `needs` empty                           | `` `needs` is empty; drop it or name a dendrite ``                             |
| a need not in the catalogue             | `needs unknown dendrite(s): …; every need must be a catalogue name`            |
| `hosts` not a list                      | `` `hosts` is a <type>, not a list of host names ``                            |
| `hosts` empty                           | `` `hosts` is empty; drop it or name a host ``                                 |
| a host not in `knownHosts`              | `is confined to unknown host(s): …`                                            |
| `homes` not a positive integer          | `` `homes` must be a positive integer, got <value> ``                          |

Two registries giving rules for one name clash, as any other field does:
`rules names defined by more than one source: '<name>' by <a> and <b>`
([Merging registries](merging.md)).

## Merging

`rules` merges by name through `mergeRegistries`, like `catalogue`, and a rule
may name an entry another registry defines. A registry with no `rules` changes
nothing: every case that held before holds now.

## The inventory

A selected entry that has a rule carries it, as written, in the host's
inventory: `inventory.dendrites.<name>.rules` (and under each user's
`dendrites` for a user's selection). An entry with no rule has no `rules` key.
