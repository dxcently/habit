# AGENTS.md — editing habit

`README.md` says what habit is. This file holds the invariants to keep while
editing it.

## Invariants

1. **Selection never reads platform configuration.** The selection pass is an
   `evalModules` over `mkSchema` that knows nothing of NixOS. Platform settings
   ride `deferredModule` options and are evaluated only in the lane selected for
   them. Anything that lets a selection option read `config` of the platform is
   the circular import the two passes exist to prevent.
2. **Unselected modules are never imported.** A catalogue entry, a provider file
   or an aggregation body is `import`ed iff selection kept it. The one weaker
   boundary is override records (read to be matched; only their functions stay
   uncalled) and is stated as such.
3. **A pure function of `lib`.** `lib/*.nix` take `{ lib }` and nothing else:
   no flake inputs, no `pkgs`, no `builtins.getFlake`, no environment. The flake
   exports them unapplied. `nixpkgs` in `flake.nix` is for `checks` only.
4. **Names are unique across merged catalogues.** Merging registries goes
   through `mergeRegistries` in `lib/catalogues.nix`, never `//`. A clash
   throws naming the name and every source defining it.
5. **The constructor knows no vocabulary.** A new field on the host record comes
   in through `selectionModules` / `extraModulesFor`, not by teaching
   `composition.nix` a word. Both hooks default to nothing.
6. **Every error names what failed.** The suite greps the real message, so a
   vague throw is a failing test.

## Extension points

- A new composition behaviour: a case in `tests/selection/cases.nix`, its line in
  `tests/selection/run.sh`, and a fixture under `tests/selection/` if it needs
  one. A positive case alone does not prove "never imported": pair it with a
  fixture that throws on import.
- A new registry field to merge: `lib/catalogues.nix`, a line in `mergeRegistries`
  through `mergeField`.

## Docs ride with code

A commit that changes a seam, an invariant or a registry or host record shape
updates `README.md` (and this file when an invariant moves) in the same commit,
never a follow-up. A comment that names a path or document must name one that
exists in this repo.

## Docs are timeless

Edit a document integrally so the page reads as if it was always the way it is.
No dated "UPDATE" or "AMENDMENT" blocks. The change record belongs in the commit
message and `CHANGELOG.md`, which is append-only.

## Code style

Names say what the code does. Comment only what the code cannot say. No plan,
slice or date labels in code or comments.
