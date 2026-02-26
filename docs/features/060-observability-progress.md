# F-060 Feature Progress Tracking

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-26

## Goal

Track progress across the app using a central feature index and per-feature documents.

## Scope

- In scope: Feature overview/index document.
- In scope: Per-feature docs with status, scope, acceptance criteria, and progress log.
- In scope: Keep document paths visible in the dashboard UI.
- Out of scope: Automated sync between docs and app status values.

## Acceptance Criteria

- [x] A feature overview document exists.
- [x] Each requested capability has a dedicated feature document.
- [x] Documents include status and acceptance checklist sections.
- [x] Dashboard references feature document paths.

## Implementation Notes

- Status values are currently duplicated in code and docs.
- Next step: Parse docs front matter/checklists to derive status automatically.

## Progress Log

- 2026-02-26: Added feature documentation structure and dashboard references.
