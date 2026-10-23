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
| ``dendrite '<name>' is wanted with different providers for its system half (<claimants>); one system takes one implementation. Either set `habit.users.<u>.dendrites.<name>.system = false` on one so it lives in that user's home only, or, if both need the system half, they are not alternatives: make them two dendrites`` | two or more users name different providers and the host holds no system half; each claimant is `user '<user>': '<provider>'` | set `system = false` on one of them; or, if both need the system half, make them two dendrites |
| ``habit: host <file> selects dendrite '<name>', and user '<user>' names provider '<p>' for it, so the user's `system` decides whether its system half applies; but `habit.users.<user>.dendrites.<name>.system` is written under a wrapper (mkIf, mkForce or mkMerge) above it, which hides it. Write `habit.users.<user>.dendrites.<name>.system` without a wrapper above it`` | a user's `system` is set under a wrapper above it, where the host selected the dendrite and the user names another provider | write the `system` line without a wrapper above it |
| ``user '<user>' sets `habit.users.<user>.dendrites.<name>.system = true` with provider '<p>', but the host holds the system half of '<name>' with '<q>'; one system takes one implementation`` | a user asks for the system half with a provider other than the one the host's system half holds | drop `system = true`, so the user has the home half alone; or name the host's provider |
| ``habit: user '<user>', dendrite '<name>': `habit.users.<user>.dendrites.<name>` sets provider '<p>' and enable = false; a provider implies enable, so drop one of the two`` | a user names a provider and also writes `enable = false` | drop one of the two lines |
| ``habit: user '<user>', aggregation '<group>': `habit.users.<user>.aggregation.<group>.<member>` sets provider '<p>' and enable = false; the group is off for this user, so the provider would be unused; drop one of the two`` | a user names a member's provider under a group they switched off | drop one of the two lines |
| `dendrite '<name>': a provider set takes only `providers`; it also has <keys>` | a provider set, a file or a value, has `providers` and a key besides it, which would be dropped | move the key out of the set, or drop it |
| `dendrite '<name>': `providers` is a <type>, not an attrset of provider targets` | `providers` is a list, string or other non-attrset | make it an attrset of name to target |
| `dendrite '<name>' provider '<p>' is a <type>; a provider is a path or a module value` | a chosen target is a number, list or `null` | make it a path, an attrset or a function |
| `dendrite '<name>' provider '<p>' is a provider set; a provider is a path or a module value` | a chosen target has `providers`; a set of sets is not a provider | make the target a module, or lift it into the outer set |
| ``A definition for option `habit.catalogue.<name>' is not of type `a path, an attrset module or a function module'. Definition values: …`` | a catalogue entry is a number, a list, `null` or a relative path; the module system's message, naming the entry and the value it got | make it a path, an attrset or a function |

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
| `habit: user '<user>' opts out of dendrite '<name>', which never reached it; remove ...` | a user writes `dendrites.<name>.enable = false`, and neither the host nor the user's own groups reach its home half | remove the opt-out |
| `habit: user '<user>' opts out of aggregation '<group>', which never reached it; remove ...` | a user writes `aggregation.<group>.enable = false` for a group the host did not select | remove the opt-out |
| ``host '<host>': `habit.dendrites.<name>.system = false` selects only the home half of '<name>' but every user with home.enable opts out of it or names another provider of it`` | the host selects only the home half of a capability and every user with a home opted out of it, or named another provider for it | drop `system = false`, or let one user keep it |
| ``host '<host>': `habit.dendrites.<name>.system = false` selects only the home half of '<name>' but no user has home.enable`` | the host selects only the home half of a capability and no user has Home Manager on to receive it; several are joined by `;` | give a user `home.enable = true`, or drop `system = false` |
| ``host '<host>': user(s) <users> have home.enable = true but no `homeManagerModule` was given`` | a user has Home Manager on and the caller gave none to import | pass Home Manager's `nixosModules.home-manager` or `darwinModules.home-manager` as `homeManagerModule` |

## Classes

| message | cause | fix |
| ------- | ----- | --- |
| `unknown class '<class>'; habit builds darwin, home, nixos` | `mkModules` was given a `class` it does not build | use `nixos`, `darwin` or `home`, or a builder |
| ``habit: host <file> sets `habit.users`; a standalone home has no users, the host module is the home itself`` | a home host module writes `habit.users` | drop it: the host module is the one home |
| ``home '<name>' was given a `homeManagerModule`; a standalone home is evaluated by Home Manager itself and imports none`` | `mkHome`, or `mkModules` for a `home`, was given `homeManagerModule` | remove it |

## Modules

A selected dendrite, provider target or user module is wrapped when it is
imported. Each message begins `<path> (habit module '<name>')`, where `<path>`
is the module's file (the `default.nix` for a catalogue entry that is a
directory), or for a catalogue value the `_file` it carries, or else
`catalogue value '<name>'`, or for a chosen provider's value
`catalogue value '<name>.<provider>'`. `<name>` is the capability or `user:<user>`.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `does not look like a module, got <type>` | the file evaluates to something other than an attrset or a function returning one | write a module |
| ``host '<host>' `habit.dendrites.<name>.system = false` selects only the home half of '<name>', which has none`` (a user's reads ``user '<user>' of host '<host>' `habit.users.<user>.dendrites.<name>.system = false` ``, then the same) | a selection asks for the home half alone of a module, or of the provider that answers it, with no `habit.home` | drop `system = false`, or give the module a `habit.home` |
| ``user '<user>' of host '<host>' `habit.users.<user>.dendrites.<name>.provider = "<p>"` (the system half is taken by '<q>') selects only the home half of '<name>', which has none`` | a user names a provider with no `habit.home`, and the host's system half is '<q>', so the user's pick is home only | name a provider with a `habit.home`, or give the module one |
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
| `is a <type>, not a path; a body is a file or a directory holding a default.nix` | the registry's entry is a set, a string or another non-path (no `aggregation '<name>' (<path>)`: there is no path to name) | make the entry a path to the body |
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
| `is a <type>, not a path; a record is a file` (no `(<path>)`: the entry is not a path) | the registry's `overrides` entry is a set, a string or another non-path | make the entry a path to the record |

These are checked on every host, matched or not.

## Registry rules

[Registry rules](rules.md). The first group is checked on every host; each
begins `rule '<name>'`, followed by ` (from registry '<source>')` when the
registry is merged. The second group is raised on a host that earns the
refusal, each prefixed `habit: `, and joined with `; ` when several apply.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `has unknown field(s): <fields>; a rule takes only needs, hosts, homes` | a field outside the three | rename or remove it |
| `names no catalogue entry; a rule is keyed by a catalogue name` | the rule's name is not in the catalogue | correct the name, or add the entry |
| `is a <type>, not an attrset; a rule takes only needs, hosts, homes` | the rule is a list or other non-attrset | make it an attrset of the three fields |
| ``: `needs` is a <type>, not a list of catalogue names`` | `needs` is a string or other non-list | make it a list |
| ``: `needs` is empty; drop it or name a dendrite`` | `needs = [ ];` | drop the field, or name a dendrite |
| `needs unknown dendrite(s): <names>; every need must be a catalogue name` | a need not in the catalogue | correct the name |
| ``: `hosts` is a <type>, not a list of host names`` | `hosts` is a string or other non-list | make it a list |
| ``: `hosts` is empty; drop it or name a host`` | `hosts = [ ];` | drop the field, or name a host |
| `is confined to unknown host(s): <hosts>` | a host not in `knownHosts` | pass every host name as `knownHosts`, or correct the name |
| ``: `homes` must be a positive integer, got <value>`` (or `got a <type>`) | `homes` is `0`, negative, or not an integer | give a whole number of at least 1 |

| message | cause | fix |
| ------- | ----- | --- |
| ``habit: host '<h>' (system): dendrite '<n>' needs '<m>', which is switched off (`habit.dendrites.<m>.enable = false`)`` | the entry is selected for the system and a need the host switched off | select the need, or drop the entry |
| ``habit: host '<h>' (system): dendrite '<n>' needs '<m>', which is not selected; select it with `habit.dendrites.<m>.enable = true` `` | the entry is selected for the system and a need is not selected at all | select the need |
| ``habit: host '<h>' (user '<u>'): dendrite '<n>' needs '<m>', which is switched off for '<u>' (`habit.users.<u>.dendrites.<m>.enable = false`)`` | a user's home reaches the entry, and that user switched the need off, with the host not selecting it | drop the user's switch, or drop the entry from the user |
| ``habit: host '<h>' (user '<u>'): dendrite '<n>' needs '<m>', which is switched off on the host (`habit.dendrites.<m>.enable = false`) and does not reach '<u>'; select it for '<u>' with `habit.users.<u>.dendrites.<m>.enable = true` `` | the host switched the need off, and the user's home does not reach it | select it for the user, or drop the entry from the user |
| ``habit: host '<h>' (user '<u>'): dendrite '<n>' needs '<m>', which is neither selected on the host nor reaches '<u>'; select it with `habit.dendrites.<m>.enable = true` or `habit.users.<u>.dendrites.<m>.enable = true` `` | the need is nowhere on this host | select it, for the host or the user |
| ``habit: dendrite '<n>' is selected on host '<h>' (<how>), but its rule allows only host(s) <hosts>`` | the entry is selected on a host the rule does not list; `<how>` is `directly`, `via aggregation '<g>'`, `by user '<u>'`, `via aggregation '<g>' of user '<u>'` or `via aggregation '<g>' on the host` | drop the selection here, or add the host to `hosts` |
| ``habit: host '<h>': dendrite '<n>' reaches the homes of <k> users (<users>), but its rule allows <N>; switch off all but <N> with `habit.users.<u>.dendrites.<n>.enable = false` for each of <users>`` | more users' homes reached than `homes` allows | switch the named users off, leaving `homes` of them |

## Merging registries

| message | cause | fix |
| ------- | ----- | --- |
| `registry source at position <n> is a <type>, not an attrset` | a source is not an attrset, often a path without `import` | `import` it |
| `registry source '<name>' has unknown field(s): <fields>; a source takes only name, catalogue, aggregations, overrides, rules` | a field outside the five (named by position when the source has no name) | rename or remove it |
| ``registry source at position <n> has no string `name`; every source is named so a clash can say who defined it`` | `name` missing or not a string | add `name = "…"` |
| `registry sources share a name: <names>; each source needs its own` | two sources with one `name` | rename one |
| ``registry source '<name>': `<field>` must be an attrset, got <type>`` | `catalogue`, `aggregations`, `overrides` or `rules` present but not an attrset | make it an attrset, or leave it out |
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
