# F-010 Caddy Installation & Updates

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-03-02

## Goal

Detect Caddy on macOS, display version information, and provide a safe update path.

## Scope

- In scope: Detect local `caddy` binary and version.
- In scope: Surface install/update commands (Homebrew-first bootstrap).
- In scope: Compare local version with latest upstream release metadata.
- Out of scope: Silent auto-update execution in this bootstrap.

## Acceptance Criteria

- [x] App can detect whether `caddy` is installed.
- [x] App displays local version and binary path when available.
- [x] App fetches latest release metadata from GitHub API.
- [x] If Caddy is missing, app attempts automatic installation (Homebrew first, direct download fallback without Homebrew).
- [x] App offers one-click update execution with confirmation and rollback/recovery handling.

## Implementation Notes

- Bootstrap implementation uses shell discovery (`command -v caddy`, `caddy version`).
- Update execution uses Homebrew (`brew update --quiet && brew upgrade caddy`) when available, otherwise a direct GitHub release binary download into the app-managed bin path.
- Automatic install bootstrap prefers Homebrew, then falls back to direct GitHub release download (`~/Library/Application Support/CaddyApp/bin/caddy`).
- If the upgrade fails, the app attempts recovery via `brew reinstall caddy` and reports the outcome.
- Version comparison is basic semver parsing and should be hardened for edge cases.
- Auto-setup repairs broken Homebrew service startup when the expected `$(brew --prefix)/etc/Caddyfile` is missing (creates a symlink to app-generated config or a fallback file, then restarts `brew services` if needed).
- Auto-setup detects and consolidates multiple simultaneously running `caddy run` processes to a single preferred instance (Homebrew service process preferred when present).

## Progress Log

- 2026-02-26: Added local install detection and release metadata fetch in dashboard service.
- 2026-02-26: Added automatic bootstrap attempt (`brew install caddy`) when Caddy is missing.
- 2026-02-26: Added explicit update-available status and one-click Homebrew update flow with confirmation + recovery fallback.
- 2026-02-26: Added Homebrew-free install/update fallback via direct GitHub release download into app-managed bin.
- 2026-03-02: Added automatic Homebrew service repair for missing `Caddyfile` to fix recurring `brew services` `error 1` startup failures.
- 2026-03-02: Added automatic multi-instance Caddy consolidation to prevent conflicting parallel `caddy run` processes.
