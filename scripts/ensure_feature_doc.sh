#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DOCS_DIR="$ROOT_DIR/docs/features"
TEMPLATE_PATH="$DOCS_DIR/FEATURE_TEMPLATE.md"

cd "$ROOT_DIR"

if [ ! -d "$DOCS_DIR" ] || [ ! -f "$TEMPLATE_PATH" ]; then
  exit 0
fi

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
STATUS_OUTPUT=$(git status --porcelain)

if [ -z "$STATUS_OUTPUT" ]; then
  exit 0
fi

if printf '%s\n' "$STATUS_OUTPUT" | awk '{print $2}' | grep -E '^docs/features/.+\.md$' >/dev/null 2>&1; then
  exit 0
fi

SHOULD_CREATE=0
if [ "${CADDYAPP_FEATURE:-0}" = "1" ]; then
  SHOULD_CREATE=1
elif printf '%s' "$BRANCH_NAME" | grep -Eiq '(^|/)(feat|feature)[/-]'; then
  SHOULD_CREATE=1
fi

if [ "$SHOULD_CREATE" -ne 1 ]; then
  exit 0
fi

NEXT_ID=$(find "$DOCS_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*.md' | \
  sed -E 's#.*/([0-9]{3})-.*#\1#' | \
  sort -n | \
  tail -n 1)

if [ -z "${NEXT_ID:-}" ]; then
  NEXT_NUM=10
else
  NEXT_NUM=$((10#$NEXT_ID + 10))
fi

DOC_ID=$(printf '%03d' "$NEXT_NUM")

FEATURE_SLUG=$(printf '%s' "$BRANCH_NAME" | sed -E 's#^.*/##; s/^(feat|feature)[/-]?//I; s/[^a-zA-Z0-9]+/-/g; s/^-+//; s/-+$//; s/.*/\L&/')
if [ -z "$FEATURE_SLUG" ]; then
  FEATURE_SLUG="auto-feature"
fi

FEATURE_TITLE="${CADDYAPP_FEATURE_TITLE:-}"
if [ -z "$FEATURE_TITLE" ]; then
  FEATURE_TITLE=$(printf '%s' "$FEATURE_SLUG" | tr '-' ' ')
fi
FEATURE_TITLE=$(printf '%s' "$FEATURE_TITLE" | awk '{for (i=1;i<=NF;i++) {$i=toupper(substr($i,1,1)) substr($i,2)}; print}')
if [ -z "$FEATURE_TITLE" ]; then
  FEATURE_TITLE="Auto Feature"
fi

TODAY=$(date +%Y-%m-%d)
DOC_PATH="$DOCS_DIR/${DOC_ID}-${FEATURE_SLUG}.md"

cat > "$DOC_PATH" <<DOC
# F-${DOC_ID} ${FEATURE_TITLE}

## Status

- State: In Progress
- Owner: TBD
- Last Updated: ${TODAY}

## Goal

Describe the user-visible outcome.

## Scope

- In scope:
- In scope:
- Out of scope:

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Implementation Notes

- Technical decisions
- Risks / constraints
- Dependencies

## Progress Log

- ${TODAY}: Auto-created by successful build on branch ${BRANCH_NAME}.
DOC

printf 'Created feature document: %s\n' "$DOC_PATH"
