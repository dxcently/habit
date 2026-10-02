#!/usr/bin/env bash
# Every ```nix block in README.md and docs/ whose first line is
# `# examples/<path>` must be that file, whole and unchanged: the docs quote
# what the selection suite evaluates, never a paraphrase of it.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

checked=0; fail=0
for md in README.md docs/*.md; do
  inblock=0; first=0; path=""; body=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [ $inblock -eq 0 ]; then
      [ "$line" = '```nix' ] && { inblock=1; first=1; path=""; body=""; }
      continue
    fi
    if [ "$line" = '```' ]; then
      inblock=0
      [ -z "$path" ] && continue
      checked=$((checked+1))
      if [ ! -f "$path" ]; then
        printf '%s: quotes %s, which does not exist\n' "$md" "$path"; fail=1
      elif [ "$body" != "$(cat "$path")" ]; then
        printf '%s: the block quoting %s differs from the file\n' "$md" "$path"; fail=1
      fi
      continue
    fi
    if [ $first -eq 1 ]; then
      first=0; body=$line
      [[ $line =~ ^#\ (examples/[^ ]+) ]] && path=${BASH_REMATCH[1]}
    else
      body+=$'\n'$line
    fi
  done < "$md"
done

printf '%d quoted example files checked\n' "$checked"
[ "$fail" -eq 0 ]
