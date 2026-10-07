# AGENTS.md — editing habit

`README.md` says what habit is, `docs/` is the reference (an mdBook, built by
`checks.x86_64-linux.docs`), and `examples/` are worked examples the selection
suite evaluates. This file holds the invariants to keep while editing them.

## Invariants

1. **Selection never reads platform values.** The selection pass is an
   `evalModules` over `mkSchema` that knows nothing of NixOS. The host is one
   module the platform evaluates too, so selection reads only its literal
   `habit.*` attribute paths and values: `lib/scan.nix` applies the host with
   `config`, `pkgs`, `options` and `osConfig` poisoned, drops its `imports` and
   never forces another key, and the platform evaluation declares `habit.*`
   inert and fails any key a file other than the host's writes, and any key
   written inline in the host's `imports` that selection does not hold. Anything that lets a selection
   option read `config` of the platform is the circular import the two passes
   exist to prevent.
2. **Unselected modules are never imported.** A catalogue entry, a provider file
   or an aggregation body is `import`ed iff selection kept it: `lanes.wrap` is
   handed selected paths only, and a wrapped module imports its file when it is
   forced. The one weaker boundary is override records (read to be matched; only
   their functions stay uncalled) and is stated as such.
3. **A pure function of `lib`.** `lib/*.nix` take `{ lib }` and nothing else:
   no flake inputs, no `pkgs`, no `builtins.getFlake`, no environment. The flake
   exports the public ones unapplied; `lib/lanes.nix` and `lib/scan.nix` are
   internal, exported by nothing and imported by `lib/composition.nix`, which
   applies them to its own `lib`. `nixpkgs` in `flake.nix` is for `checks` only.
4. **Names are unique across merged catalogues.** Merging registries goes
   through `mergeRegistries` in `lib/catalogues.nix`, never `//`. A clash
   throws naming the name and every source defining it.
5. **The constructor knows no consumer's vocabulary.** It knows habit's own
   words: `habit.dendrites`, `habit.aggregation`, `habit.users`, `habit.home`,
   `habit.selected` and the registry's fields. A consumer's key under `habit`
   comes in through `selectionModules` / `extraModulesFor`, not by teaching
   `composition.nix` a word, and may not take one of habit's names. Both hooks
   default to nothing.
6. **Every error names what failed.** The suite greps the real message, so a
   vague throw is a failing test.

## Extension points

- A new composition behaviour: a case in `tests/selection/cases.nix`, its line in
  `tests/selection/run.sh`, and a fixture under `tests/selection/` if it needs
  one (a host under `hosts/`). A positive case alone does not prove "never
  imported": pair it with a fixture that throws on import.
- A new registry field to merge: `lib/catalogues.nix`, a line in `mergeRegistries`
  through `mergeField`.
- A new example: a directory under `examples/` whose `default.nix` takes
  `{ habit, nixpkgs, home-manager }`, its cases in the examples section of
  `tests/selection/cases.nix` (inventory, module list, an option value) and their
  rows in `tests/selection/run.sh`. Each file starts `# examples/<its path>`.
- A new docs page: the file in `docs/` and its line in `docs/SUMMARY.md`.

## Docs ride with code

A commit that changes a seam, an invariant or a registry or host module shape
updates, in the same commit and never a follow-up: `README.md`, the `docs/` page
that describes it, the examples it changes, and this file when an invariant
moves. A comment or page that names a path or document must name one that
exists in this repo, unless it names the file of another repository together
with the revision it was read at (`docs/comparisons.md` does).

Docs quote example files whole, never a paraphrase: a ```` ```nix ```` block
whose first line is `# examples/<path>` must equal that file, which
`tests/docs/quotes.sh` checks before the book builds. Links from `docs/` to
files outside it use `https://github.com/dxcently/habit/blob/main/<path>`, since
the book is served without them.

## Docs are timeless

Edit a document integrally so the page reads as if it was always the way it is.
No dated "UPDATE" or "AMENDMENT" blocks. The change record belongs in the commit
message and `CHANGELOG.md`, which is append-only.

## Code style

Names say what the code does. Comment only what the code cannot say. No plan,
slice or date labels in code or comments.
