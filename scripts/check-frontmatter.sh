#!/usr/bin/env bash
# Validate YAML frontmatter on skills and agents.
#   - every skills/**/SKILL.md must declare a `description`
#   - every agents/*.md must declare `name` and `description`
# No external dependencies (bash + awk + grep), so it runs identically in CI.
set -uo pipefail

fail=0

# Print the frontmatter block: lines between the first '---' and the next '---'.
# Exits non-zero (prints nothing) when the file has no leading '---'.
frontmatter() {
  awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    { print }
  ' "$1"
}

has_key() { grep -Eq "^[[:space:]]*$2:" <<<"$1"; }

check_file() { # $1=file  $2...=required keys
  local f="$1"; shift
  local fm miss=""
  fm="$(frontmatter "$f")" || { echo "  FAIL $f — no frontmatter block"; fail=1; return; }
  for key in "$@"; do has_key "$fm" "$key" || miss="$miss $key"; done
  if [ -n "$miss" ]; then echo "  FAIL $f — missing:$miss"; fail=1; else echo "  ok   $f"; fi
}

while IFS= read -r f; do check_file "$f" description; done \
  < <(find skills -name SKILL.md 2>/dev/null | sort)

while IFS= read -r f; do check_file "$f" name description; done \
  < <(find agents -name '*.md' 2>/dev/null | sort)

exit $fail
