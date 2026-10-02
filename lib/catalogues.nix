# lib/catalogues.nix — merging registries from more than one source.
#
# Merging with `//` lets the right-hand side silently win a name both sides
# define, and the capability that loses is simply gone. Here a name defined by
# more than one source is an error that says which name and which sources.
#
# A source is a registry plus the name to blame it by:
#
#   { name = "aoide"; catalogue = { … }; aggregations = { … }; overrides = { … }; }
#
# Any of the three fields may be absent; one that is present must be an attrset.
# Source names must be unique, or an error could not say which source clashed.
# `mergeRegistries` returns a registry, ready to hand to the constructor. Each
# of its fields is merged on its own and only when read, so a clash is reported
# by the field it is in. Like composition.nix this is a function of `{ lib }`
# and nothing else.
{ lib }:
let
  sourceName =
    index: source:
    if !(source ? name) || !(lib.isString source.name) then
      throw "registry source at position ${toString index} has no string `name`; every source is named so a clash can say who defined it"
    else
      source.name;

  fieldOf =
    field: source:
    let
      value = source.${field} or { };
    in
    if lib.isAttrs value then
      value
    else
      throw "registry source '${source.name}': `${field}` must be an attrset, got ${builtins.typeOf value}";

  mergeField =
    field: sources:
    let
      names = lib.imap1 sourceName sources;
      repeated = lib.unique (lib.filter (n: lib.count (m: m == n) names > 1) names);

      ownersOf = lib.zipAttrsWith (_: owners: owners) (
        map (source: lib.mapAttrs (_: _: source.name) (fieldOf field source)) sources
      );
      clashes = lib.filterAttrs (_: owners: lib.length owners > 1) ownersOf;
      describe = lib.mapAttrsToList (
        name: owners: "'${name}' by ${lib.concatStringsSep " and " owners}"
      ) clashes;
    in
    if repeated != [ ] then
      throw "registry sources share a name: ${lib.concatStringsSep ", " repeated}; each source needs its own"
    else if clashes != { } then
      throw "${field} names defined by more than one source: ${lib.concatStringsSep "; " describe}"
    else
      lib.foldl' (merged: source: merged // fieldOf field source) { } sources;
in
{
  mergeRegistries = sources: {
    catalogue = mergeField "catalogue" sources;
    aggregations = mergeField "aggregations" sources;
    overrides = mergeField "overrides" sources;
  };
}
