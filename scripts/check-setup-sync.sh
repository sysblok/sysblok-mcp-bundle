#!/usr/bin/env bash
# Verifies that SETUP.md's inlined BEGIN-SYNC/END-SYNC blocks stay
# byte-identical to the real tracked files. The tracked files are the
# source of truth; SETUP.md's copies must match them, not the other way
# around. Run locally before pushing, or via CI (see .github/workflows/ci.yml).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
setup_md="$repo_root/SETUP.md"
status=0

extract_block() {
  local marker="$1"
  awk -v marker="$marker" '
    $0 ~ "<!-- BEGIN-SYNC: " marker " -->" { capture=1; next }
    $0 ~ "<!-- END-SYNC: " marker " -->" { capture=0 }
    capture && $0 !~ /^```/ { print }
  ' "$setup_md"
}

check_file() {
  local file="$1"
  local extracted
  extracted="$(extract_block "$file")"

  if [ -z "$extracted" ]; then
    echo "ERROR: no BEGIN-SYNC/END-SYNC block found for '$file' in SETUP.md"
    status=1
    return
  fi

  local diff_output
  if diff_output="$(diff -u "$repo_root/$file" <(printf '%s\n' "$extracted"))"; then
    echo "OK: $file matches its SETUP.md inlined copy"
  else
    echo "ERROR: $file has drifted from its SETUP.md inlined copy:"
    echo "$diff_output"
    status=1
  fi
}

check_file "docker-compose.yml"
check_file ".env.example"
check_file "client-config.example.json"

exit "$status"
