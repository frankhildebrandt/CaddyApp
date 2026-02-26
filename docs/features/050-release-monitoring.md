# F-050 Caddy Release Monitoring

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-26

## Goal

Monitor new Caddy releases and notify the user when an update is available.

## Scope

- In scope: Fetch latest release metadata from GitHub Releases API.
- In scope: Show tag, publication time (when available), and release URL.
- In scope: Compare with local version and prepare update suggestion.
- Out of scope: Background scheduling/notifications in bootstrap version.

## Acceptance Criteria

- [x] App fetches latest Caddy release metadata from GitHub API.
- [x] App displays release tag and URL in the dashboard.
- [x] App displays explicit "update available" state using version comparison.
- [ ] App runs periodic checks in background and shows notifications.

## Implementation Notes

- API endpoint: `https://api.github.com/repos/caddyserver/caddy/releases/latest`.
- A future revision should handle rate limits, caching, and offline fallback.
- Background checks/notifications remain out of scope for the bootstrap version and are tracked as follow-up work.

## Progress Log

- 2026-02-26: Added GitHub release fetcher and dashboard integration.
- 2026-02-26: Surfaced explicit update state (up-to-date vs update available) and release publication timestamp in dashboard.
