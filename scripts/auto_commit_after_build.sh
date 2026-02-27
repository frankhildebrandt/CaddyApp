#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$ROOT_DIR"

if [ "${CADDYAPP_SKIP_AUTOCOMMIT:-0}" = "1" ]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
  exit 0
fi

if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

"$SCRIPT_DIR/ensure_feature_doc.sh"

git add -A

if [ -z "$(git diff --cached --name-only)" ]; then
  exit 0
fi

CHANGED_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
CHANGED_PREVIEW=$(git diff --cached --name-only | head -n 3 | tr '\n' ', ' | sed 's/, $//')

if [ "$CHANGED_COUNT" -le 3 ]; then
  COMMIT_MSG="chore: update ${CHANGED_PREVIEW}"
else
  COMMIT_MSG="chore: update ${CHANGED_PREVIEW} (+$((CHANGED_COUNT - 3)) more)"
fi

git commit -m "$COMMIT_MSG" >/dev/null
printf 'Auto-commit created: %s\n' "$COMMIT_MSG"
