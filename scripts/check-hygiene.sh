#!/usr/bin/env bash
# Fail if any OS/editor junk file is tracked in git. Dependency-free.
set -uo pipefail

junk="$(git ls-files \
  | grep -E '(^|/)(\.DS_Store|Thumbs\.db|desktop\.ini)$|\.(orig|rej|bak|swp|swo)$' \
  || true)"

if [ -n "$junk" ]; then
  echo "  FAIL tracked junk files:"
  printf '%s\n' "$junk" | sed 's/^/    /'
  exit 1
fi

echo "  ok   no junk files tracked"
