# Errors

Every error habit throws names what failed. The text below is the real
message, with the parts that vary in angle brackets. Errors raised by the
module system on habit's schema and the modules it routes are listed after
them.

## Selecting capabilities

| message | cause | fix |
| ------- | ----- | --- |
| `dendrite '<name>' is enabled but chose no provider; available providers: <list>` | a provider-bearing capability is enabled and nothing chose a provider | set `habit.dendrites.<name>.provider`, or select it through a group whose body names a default |
| `dendrite '<name>' has no provider '<p>'; available providers: <list>` | the chosen provider is not in the dendrite's `providers` | choose one from the list |
| `dendrite '<name>' has a single implementation and takes no provider (got '<p>')` | a provider was set on a dendrite that is a plain module | remove the `provider` |
| `dendrite '<name>' is selected with different providers (<claimants>); one system takes one implementation` | the host and a user, or two users, selected one capability with different providers; each claimant is `host` or `user '<user>'`, then its provider | make every selector name the same provider |

## The host module

The host is read by the scan before NixOS evaluates anything
([The host module](host.md#the-scan)). Each message begins `habit: host <file>`,
where `<file>` is the host's path.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| ``reads `<argument>` while selection is being read; selection may not depend on platform configuration`` | a `habit` key reads `config`, `pkgs`, `options` or `osConfig`, directly or through `mkIf`; `<argument>` is that one | write the key as a literal, and keep platform-dependent settings outside `habit` |
| `takes argument(s) <name> which the scan does not provide; pass them in specialArgs` | a `habit` key reads an argument of the host's head (an input, a username) that the caller's `specialArgs` do not hold; one read only under `imports` is never missed | add it to `specialArgs` |
| `does not look like a module, got <type>` | the host evaluates to something other than an attrset or a function returning one | write a module |

Two more come from the platform evaluation and the hooks:

| message | cause | fix |
| ------- | ----- | --- |
| ``Failed assertions: `habit.<path>` is set in <file> but the host scan never saw it (scans do not follow `imports`)`` | a `habit.*` key written by a file other than the host's (an imported file, an `extraModules` entry), or inline in the host's own `imports` with a value selection does not hold | write the key in the host file itself |
| ``selection module <file> declares habit.<name>; habit reserves dendrites, aggregation, users, selected, home`` | a `selectionModules` module declares one of habit's own names | rename the option |

## Users

| message | cause | fix |
| ------- | ----- | --- |
| `host '<host>': user '<user>' has home.enable = false but selects home dendrites: <list>` | a user selects home capabilities with their home off | set `home.enable = true`, or drop the selections |
| ``host '<host>': `habit.dendrites.<name>.system = false` selects only the home half of '<name>' but no user has home.enable`` | the host selects only the home half of a capability and no user has Home Manager on to receive it; several are joined by `;` | give a user `home.enable = true`, or drop `system = false` |
| ``host '<host>': user(s) <users> have home.enable = true but no `homeManagerModule` was given`` | a user has Home Manager on and the caller gave none to import | pass Home Manager's `nixosModules.home-manager` or `darwinModules.home-manager` as `homeManagerModule` |

## Classes

| message | cause | fix |
| ------- | ----- | --- |
| `unknown class '<class>'; habit builds darwin, home, nixos` | `mkModules` was given a `class` it does not build | use `nixos`, `darwin` or `home`, or a builder |
| ``habit: host <file> sets `habit.users`; a standalone home has no users, the host module is the home itself`` | a home host module writes `habit.users` | drop it: the host module is the one home |
| ``home '<name>' was given a `homeManagerModule`; a standalone home is evaluated by Home Manager itself and imports none`` | `mkHome`, or `mkModules` for a `home`, was given `homeManagerModule` | remove it |

## Modules

A selected dendrite, provider file or user module is wrapped when it is
imported. Each message begins `<path> (habit module '<name>')`, where `<path>`
is the module's file (the `default.nix` for a catalogue entry that is a
directory) and `<name>` is the capability or `user:<user>`.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `does not look like a module, got <type>` | the file evaluates to something other than an attrset or a function returning one | write a module |
| ``host '<host>' `habit.dendrites.<name>.system = false` selects only the home half of '<name>', which has none`` (a user's reads ``user '<user>' of host '<host>' `habit.users.<user>.dendrites.<name>.system = false` ``, then the same) | a selection asks for the home half alone of a module, or of the provider that answers it, with no `habit.home` | drop `system = false`, or give the module a `habit.home` |
| `` `habit.home`: does not look like a module, got <type> `` | `habit.home` is a number, list or other non-module | write `habit.home` as an attrset, a function or a path |
| `` `habit.home`: carries `imports` or `options` under a condition; a condition covers only what the half sets, so move them out of it `` | in a standalone home, `habit.home`, or the module's config, is under `mkIf` and the half has `imports` or `options` | put them in a `habit.home` that no `mkIf` covers; for a user the `mkIf` covers them |
| `has an unsupported top-level attribute: <names>; put configuration under `config`` | a module with `options` or `config` also has a stray top-level key | move it under `config` |
| `config must be an attribute set, got <type>` | `config` is a list or other non-attrset | make it an attrset |
| ``config is a `<type>` value habit cannot split`` | `config` is an `mkOrder` or another module-system value that is not `mkIf`, `mkMerge` or `mkOverride` | write the configuration as an attrset, or wrap it in one of those three |
| ``unknown habit key(s): <keys>; only `home` is read`` | a key under `habit` other than `home` (`habit.homee`, `habit.selected`, a selection such as `habit.dendrites`) | rename or remove it |
| `` `habit` is a `<type>` value; write habit.home as a plain attribute `` | `habit = mkIf …` or another wrapped `habit`: the wrapper cannot split it without evaluating the condition | write `habit.home` as a plain attribute |
| `` `habit` must be an attribute set holding `home`, got <type> `` | `habit` is a number, list or other non-attrset | make it an attrset |

## Aggregation bodies

Each begins `aggregation '<name>' (<path to its default.nix>)`. Checked for a
selected aggregation only, when its body is read.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `is a <type>, not an attrset; a body is an attrset taking only description, system, home` | the body is a function (written like a dendrite), a list or another non-attrset | make it an attrset |
| `has unknown field(s): <fields>; a body takes only description, system, home` | a misspelt half (`sytem`) or another key at the top of the body | rename or remove it |
| ``has unknown field(s) in `<half>`: <fields>; a half takes only members, providers, module`` | a key in `system` or `home` the constructor does not read (`member`, `nixos`); `<half>` is `system` or `home` | rename or remove it |
| ``has `<half>` as a <type>, not an attrset; a half is an attrset taking only members, providers, module`` | `system` or `home` is a list, string or other non-attrset | make it an attrset |

## Override records

Each begins `override record '<name>' (<path>)`.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `has unknown field(s): <fields>; a record takes only dendrites, hosts, overlay, system, home` | a misspelt or unsupported field (`nixos`, `homeManager`, `darwin`) | rename or remove it |
| `names no dendrites; a record must say which capabilities it is about` | `dendrites` missing, empty, or not a list | list the catalogue names it fixes |
| `targets unknown dendrite(s): <names>; every target must be a catalogue name` | a target not in the catalogue | correct the name, or add the capability |
| `is confined to unknown host(s): <hosts>` | `hosts` names a host not in `knownHosts` | pass every host name as `knownHosts`, or correct the name |
| `carries nothing to apply; give it an overlay, a system module or a home module` | none of `overlay`, `system`, `home` | add one, or delete the record |

These are checked on every host, matched or not.

## Merging registries

| message | cause | fix |
| ------- | ----- | --- |
| `registry source at position <n> is a <type>, not an attrset` | a source is not an attrset, often a path without `import` | `import` it |
| `registry source '<name>' has unknown field(s): <fields>; a source takes only name, catalogue, aggregations, overrides` | a field outside the four (named by position when the source has no name) | rename or remove it |
| ``registry source at position <n> has no string `name`; every source is named so a clash can say who defined it`` | `name` missing or not a string | add `name = "…"` |
| `registry sources share a name: <names>; each source needs its own` | two sources with one `name` | rename one |
| ``registry source '<name>': `<field>` must be an attrset, got <type>`` | `catalogue`, `aggregations` or `overrides` present but not an attrset | make it an attrset, or leave it out |
| `<field> names defined by more than one source: '<n>' by <a> and <b>` | a name in more than one source's `<field>` | rename one side, or drop the duplicate |

## From the module system

habit's schema and the modules it routes are ordinary modules, so a name they
do not have fails the ordinary way, naming the file that set it when that module
was given as a path:

| message | cause |
| ------- | ----- |
| ``The option `habit.dendrites.<name>' does not exist.`` | a capability not in the catalogue, or a group member naming one |
| ``The option `habit.aggregation.<group>' does not exist.`` | a group not in the registry |
| ``The option `habit.aggregation.<group>.<member>' does not exist.`` | a provider selector the group does not own in that scope |
| ``The option `habit.<key>' does not exist.`` | a key under `habit` nothing declared: a misspelt one (`habit.dendrtes`, with the nearest names suggested) or a host field to declare with `selectionModules`; also a `habit.home` written by a file a dendrite imports |
| ``The option `habit.dendrites.<name>.provider' has conflicting definition values`` | two selected groups chose different providers for one member |
| ``The option `<key>' does not exist.`` | a key of a dendrite's own configuration that no module declares where its system half is evaluated: a misspelt option, an option the platform does not have (a NixOS-only option on nix-darwin), or a set of named lanes (`{ body; nixos; homeManager; }`), which habit reads as an ordinary module |
| ``The option `<name>' in `<file>' is already declared in `<file>'.`` | a catalogue file that declares options and is selected, and is also imported by hand ([Dendrites](dendrites.md#what-is-not-a-module)) |
| ``The option `habit.selected' is read-only, but it's set multiple times.`` | something other than the constructor defines `habit.selected`, in the host's evaluation or, as `home-manager.users.<user>.habit.selected`, in a user's home |
