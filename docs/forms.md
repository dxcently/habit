# What a capability can be

A catalogue entry says what a capability is by its shape, and a host says
whether it wants it. Each row is one form, with the place that shows it.
[Growing a capability](growing-a-capability.md) builds these up one at a time.

| form | looks like | when | shown in |
| --- | --- | --- | --- |
| a file | `shell = ./dendrites/shell.nix;` | one NixOS module | [step 1](growing-a-capability.md#1-one-file) |
| a directory | `shell = ./dendrites/shell;`, its `default.nix` the module | the module wants files beside it | [step 2](growing-a-capability.md#2-a-home-half) |
| a module with a home half | `habit.home = { … };` inside the module | settings for a user's home, not the system | [step 2](growing-a-capability.md#2-a-home-half) |
| a module value | an attrset or function in the registry | written where its inputs are in scope | [step 3](growing-a-capability.md#3-providers), `fish` |
| a family of values | `lib.genAttrs names (name: { … })` | one entry per name | not in a step: [value entries](dendrites.md#value-entries) |
| a provider set in files | `providers = { bash = ./bash.nix; zsh = ./zsh.nix; };` | several implementations, each a file | [step 3](growing-a-capability.md#3-providers) |
| a provider set as a value | `shell = { providers = { …; }; };` in the registry | a set whose inputs are in scope where it is written | [step 3](growing-a-capability.md#3-providers) |
| chosen per user | `habit.users.alice.dendrites.shell.provider` | refused on one system: a user takes the host's provider | [step 4](growing-a-capability.md#4-users), the refusal |
| per home, by a standalone home | `habit.dendrites.shell.provider = "fish";` in the home's host | each home is its own selection | [`examples/full`](https://github.com/dxcently/habit/tree/main/examples/full), `hosts/alice` |
| opted out | `habit.users.bob.dendrites.shell.enable = false;` | a user without a home half the host sent | [step 4](growing-a-capability.md#4-users) |
| grouped in an aggregation | `habit.aggregation.terminal.enable = true;` | several capabilities selected together | [step 5](growing-a-capability.md#5-terminal) |
| reacting to another's selection | `config.habit.selected.shell.provider` | a capability reads what else was chosen, without importing it | [step 5](growing-a-capability.md#5-terminal) |
| fixed by an override record | `overrides = { name = ./overrides/name.nix; };` | a fix that belongs to a capability | [step 6](growing-a-capability.md#6-override) |
| a shared two-file piece | `imports = [ ./piece.nix ]; habit.home.imports = [ ./piece-home.nix ];` | two entries need one piece with both halves | [step 7](growing-a-capability.md#7-shared) |
| from another registry | `catalogues.mergeRegistries [ core personal ]` | a second source names some of the capabilities | [`examples/full`](https://github.com/dxcently/habit/tree/main/examples/full), `modules/personal` |

## How an entry resolves

```
catalogue entry
├── path ─────────────── a module, or a directory whose default.nix is one
│                        (imported only when a scope selected it)
├── value ────────────── an attrset or a function, applied only when selected
└── { providers = … } ── a provider set
      └── the chosen target: a path or a value; the other targets are never read
```

## Branches

- **One provider per system.** Host and users agree on a provider, or the build
  refuses, naming every claimant ([step 4](growing-a-capability.md#4-users)).
  A different provider per home needs a home of its own.
- **A group sends its home half to users; a user opts out of it.** The system
  half stays on the host ([Opting out](host.md#opting-out)).
- **A shared piece with a bare or inline import is declared twice.** The file
  is one identity only when it is imported by path
  ([A piece several entries share](dendrites.md#a-piece-several-entries-share)).
