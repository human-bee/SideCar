#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== git status =="
git status --short --branch

echo "== tracked secret-bearing files =="
if git ls-files | grep -Ev '(^|/)\.env\.example$' | grep -E '(^|/)(\.env|\.env\..*|.*\.sqlite|.*\.db|.*\.crash|.*\.xcuserstate)$'; then
  echo "Refusing to share: secret/private/generated file is tracked." >&2
  exit 1
fi
echo "none"

echo "== ignored local state check =="
for path in .env .codex .build dist; do
  if [[ -e "$path" ]]; then
    if git check-ignore -q "$path"; then
      echo "$path ignored"
    else
      echo "Refusing to share: $path exists and is not ignored." >&2
      exit 1
    fi
  fi
done

echo "== tests =="
swift test

echo "Share audit passed."
