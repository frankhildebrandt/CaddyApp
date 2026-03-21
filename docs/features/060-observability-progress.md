# F-060 Feature Progress Tracking

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-03-21

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
- [x] Monitoring log view supports live-watch without rendering the full logfile into the window.
- [x] Dashboard surfaces runtime backend connectivity issues with retry/backoff context.

## Implementation Notes

- Status values are currently duplicated in code and docs.
- Next step: Parse docs front matter/checklists to derive status automatically.
- Runtime-shell failures now back off exponentially up to 30 seconds to reduce pointless polling when local backends are unavailable.

## Progress Log

- 2026-02-26: Added feature documentation structure and dashboard references.
- 2026-03-21: Added bounded live-watch rendering for the Monitoring log view and surfaced Podman/Docker/Multipass shell-backoff issues in the dashboard.
