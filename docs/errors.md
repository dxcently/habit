# Errors

Every error habit throws names what failed. The text below is the real
message, with the parts that vary in angle brackets. Errors raised by the
module system on habit's schema are listed after them.

## Selecting capabilities

| message | cause | fix |
| ------- | ----- | --- |
| `dendrite '<name>' is enabled but chose no provider; available providers: <list>` | a provider-bearing capability is enabled and nothing chose a provider | set `dendrites.<name>.provider`, or select it through a group whose body names a default |
| `dendrite '<name>' has no provider '<p>'; available providers: <list>` | the chosen provider is not in the dendrite's `providers` | choose one from the list |
| `dendrite '<name>' has a single implementation and takes no provider (got '<p>')` | a provider was set on a lane-record dendrite | remove the `provider` |
| `dendrite '<label>' is selected <scope> but exposes no <lane> lane; it supports: <lanes>` | a scope asked for a lane the dendrite (or its chosen provider, `<name>/<provider>`) does not have; `<scope>` is `for the system` or `by user '<user>'` | select it in the scope it supports, or add the lane |

## Users

| message | cause | fix |
| ------- | ----- | --- |
| `host '<host>': user '<user>' has homeManager.enable = false but selects home dendrites: <list>` | a user selects home capabilities with the home lane off | set `homeManager.enable = true`, or drop the selections |
| `user '<user>' definition <path> exposes no nixos lane; it cannot create an account on this host` | the user definition has no `nixos` attribute | give the definition a `nixos` lane that creates the account |

## Assembling the module list

| message | cause | fix |
| ------- | ----- | --- |
| ``host '<host>': <path> is the whole dendrite tree, which imports every dendrite's body, and <names> is selected, so its lane imports that same body — one module list, the same declarations twice, which nixpkgs throws on as `already declared'. Keep one: select through the catalogue and drop the aggregate, or take the aggregate and select nothing.`` | `extraModules` or `extraModulesFor` returned the directory holding the catalogue entries while a capability is selected | do what the message says ([the whole-tree refusal](constructor.md#the-whole-tree-refusal)) |

## Aggregation bodies

Each begins `aggregation '<name>' (<path to its default.nix>)`. Checked for a
selected aggregation only, when its body is read.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `has unknown field(s): <fields>; a body takes only description, system, home` | a misspelt half (`sytem`) or another key at the top of the body | rename or remove it |
| ``has unknown field(s) in `<half>`: <fields>; a half takes only members, providers, nixos, homeManager`` | a key in `system` or `home` the constructor does not read (`member`, `nixso`); `<half>` is `system` or `home` | rename or remove it |

## Override records

Each begins `override record '<name>' (<path>)`.

| message continues | cause | fix |
| ----------------- | ----- | --- |
| `has unknown field(s): <fields>; a record takes only dendrites, hosts, overlay, nixos, homeManager` | a misspelt or unsupported field (`nixOS`, `darwin`) | rename or remove it |
| `names no dendrites; a record must say which capabilities it is about` | `dendrites` missing, empty, or not a list | list the catalogue names it fixes |
| `targets unknown dendrite(s): <names>; every target must be a catalogue name` | a target not in the catalogue | correct the name, or add the capability |
| `is confined to unknown host(s): <hosts>` | `hosts` names a host not in `knownHosts` | pass every host name as `knownHosts`, or correct the name |
| `carries nothing to apply; give it an overlay, a nixos module or a homeManager module` | none of `overlay`, `nixos`, `homeManager` | add one, or delete the record |

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

habit's schema is an ordinary module, so a name it does not have fails the
ordinary way, naming the file that set it when that module was given as a path:

| message | cause |
| ------- | ----- |
| ``The option `dendrites.<name>' does not exist.`` | a capability not in the catalogue, or a group member naming one |
| ``The option `aggregation.<group>' does not exist.`` | a group not in the registry |
| ``The option `aggregation.<group>.<member>' does not exist.`` | a provider selector the group does not own in that scope |
| ``The option `<field>' does not exist.`` | a host record field nothing declared; declare it with `selectionModules` |
| ``The option `dendrites.<name>.provider' has conflicting definition values`` | two selected groups chose different providers for one member |
| ``The option `users.<user>.nixos' does not exist.`` | a group's `home` half carries `nixos` |
| ``The option `homeManager' does not exist.`` | a group's `system` half carries `homeManager` |
