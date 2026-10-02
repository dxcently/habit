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
# Any of the three fields may be absent. Each merge reads only its own field and
# returns the merged attrset, ready to sit in a registry. Like composition.nix
# this is a function of `{ lib }` and nothing else.
{ lib }:
let
  mergeField =
    field: sources:
    let
      ownersOf = lib.zipAttrsWith (_: owners: owners) (
        map (source: lib.mapAttrs (_: _: source.name) (source.${field} or { })) sources
      );
      clashes = lib.filterAttrs (_: owners: lib.length owners > 1) ownersOf;
      describe = lib.mapAttrsToList (
        name: owners: "'${name}' by ${lib.concatStringsSep " and " owners}"
      ) clashes;
    in
    if clashes != { } then
      throw "${field} names defined by more than one source: ${lib.concatStringsSep "; " describe}"
    else
      lib.foldl' (merged: source: merged // (source.${field} or { })) { } sources;
in
{
  mergeCatalogues = mergeField "catalogue";
  mergeAggregations = mergeField "aggregations";
  mergeOverrides = mergeField "overrides";
}
