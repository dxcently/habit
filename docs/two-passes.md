# The two passes

A host is built in two evaluations. The first decides what the host is made
of; the second imports exactly that and nothing else.

```
host record ──► selection pass ──► resolved selection ──► platform pass ──► module list
                (evalModules,                              (imports only
                 knows nothing                              what selection
                 of NixOS)                                  kept)
```

## Why selection cannot live inside NixOS

The obvious way to make a capability optional is to import it everywhere and
guard its body:

```nix
{ config, lib, ... }:
{
  options.my.printing.enable = lib.mkEnableOption "printing";
  config = lib.mkIf config.my.printing.enable { services.printing.enable = true; };
}
```

That module is still imported on every host. Its option declarations exist on
every host, its `imports` are collected on every host, and anything it reads
at the top level is evaluated on every host. `mkIf` only withholds its
`config`. `mkDefault` does not help either: it sets a definition's priority,
and priority decides which value wins, never whether a module is imported.

The decision has to be made before the NixOS evaluation it shapes starts. It
also cannot read that evaluation's `config`: a selection that depends on the
configuration it is choosing is a circular import. So habit evaluates the
selection on its own:

| pass      | evaluates                                    | reads                      | produces                         |
| --------- | -------------------------------------------- | -------------------------- | -------------------------------- |
| selection | `lib.evalModules` over a small schema         | the registry, host modules | the resolved selection           |
| platform  | nothing; it assembles a list                  | the resolved selection     | the module list, `specialArgs`, the inventory |
| NixOS     | `nixosSystem` over that list                  | the module list            | the system                       |

The selection schema (`mkSchema` in `lib/composition.nix`) declares only
selection options: `dendrites`, `aggregation`, `users`, `nixos` and a
read-only `catalogue`. No NixOS option is declared there, so a host record
cannot read one. Platform settings (the host's own `nixos`, an aggregation's
`nixos`, a user's `homeManager.config`) are `deferredModule` options: the
selection pass carries them as values and the platform pass hands them to the
evaluator they are for.

## Selection: gate, then select

A host chooses a provider under the aggregation that owns it:

```nix
aggregation.desktop.notifications.provider = "dunst";
```

The option `aggregation.desktop.notifications` exists only because the
`desktop` body says `notifications` is one of its provider-bearing members.
Its name comes from the body, so the body must be read before the option can
be declared, and a body must not be read unless the host selected it. The
selection pass therefore runs twice:

```
            ┌──────────────── gate ────────────────┐   ┌──────────── select ─────────────┐
registry ──►│ every aggregation declares `enable`   │──►│ selected bodies are imported,    │──► resolved
host     ──►│ only; the rest is freeform, ignored   │   │ declare their provider options,  │    selection
            │ answer: which aggregations the host,  │   │ and write their membership       │
            │ or one of its users, selected         │   │ (mkDefault)                      │
            └───────────────────────────────────────┘   └──────────────────────────────────┘
```

- **gate**: every aggregation in the registry declares only `enable`; the
  rest of its attrset is accepted and ignored. No body is read. The answer is
  the set of aggregations the host, or one of its users, selects.
- **select**: the selected bodies are imported, declare their real nested
  options, and write their membership. Nothing else is read. A selector the
  body does not own (`aggregation.desktop.compositor.provider`) now fails as
  an option that does not exist.

An aggregation body is data, so it has no way to enable another aggregation:
the gate step's answer is the select step's answer. Both steps receive the
same host modules, plus any `selectionModules` the caller passes
([The constructor](constructor.md#the-two-hooks)).

## Platform: import what was kept

The platform pass walks the resolved selection and, per scope, imports the
lane each selected capability exposes: the `nixos` lane for the system, the
`homeManager` lane for each user who selected it. It is the only place
anything from the catalogue is `import`ed.

## The evaluation boundary

| thing                   | read when                                                       |
| ----------------------- | --------------------------------------------------------------- |
| the registry            | always; it is names and paths only                              |
| an aggregation body     | iff the host or one of its users selected that aggregation      |
| a catalogue entry       | iff a scope enabled that capability (platform pass)             |
| a provider file         | iff it is the provider chosen for an enabled capability         |
| a user's definition     | for every user on the host                                      |
| an override record file | always, on every host (see [Override records](overrides.md#the-evaluation-boundary)) |

Each "iff" is proved in `tests/selection` by a fixture that throws when it is
imported: `dendrites/landmine`, `dendrites/notifications/landmine.nix`,
`aggregations/landmine`, and in the examples, `printing` swapped for a throwing
body after the host switched it off.
