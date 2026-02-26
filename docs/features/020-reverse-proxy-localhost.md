# F-020 Reverse Proxy for *.localhost

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-26

## Goal

Manage reverse proxy routes for local services using `*.localhost` and generate a valid Caddyfile preview.

## Scope

- In scope: Route model (`host`, `upstream`, `source`, `enabled`).
- In scope: Caddyfile generation preview with `tls internal` and `reverse_proxy`.
- In scope: Wildcard `*.localhost` placeholder site block.
- Out of scope: Persisting route changes to disk in this bootstrap.

## Acceptance Criteria

- [x] Bootstrap includes route models for manual and discovered services.
- [x] App generates a Caddyfile preview for enabled routes.
- [x] Generated config includes `tls internal` for localhost sites.
- [x] App can write generated config to disk.
- [x] App can run `caddy validate` against the generated config.
- [x] App can trigger `caddy reload` using the generated config (basic bootstrap flow).
- [x] App auto-reloads Caddy when the generated config changes and validates successfully.
- [x] App writes config to disk and reloads Caddy safely with confirmations/rollback handling.

## Implementation Notes

- Current preview uses a fixed path target in `~/Library/Application Support/CaddyApp/Caddyfile`.
- The wildcard block is included as a convenience/diagnostic placeholder.
- Next step is a config writer plus `caddy validate` and `caddy reload` integration.
- `Validate` and `Reload` now write the current preview to disk first to avoid missing-file errors on first use.
- `Reload` falls back to `caddy start` when no running Caddy instance is listening on the admin endpoint.
- Manual `Reload Caddy` now uses a confirmation dialog and restores the previous Caddyfile automatically if pre-reload validation or reload/start fails.
- If `reload`/`start` needs elevated rights (for example privileged ports), the app retries via the macOS administrator dialog instead of a hidden CLI password prompt.
- On app startup, the dashboard auto-starts Caddy with the generated config when Caddy is installed but not running.

## Progress Log

- 2026-02-26: Added route model and generated Caddyfile preview panel.
- 2026-02-26: Added bootstrap actions for write/validate/reload with UI status output.
- 2026-02-26: Added automatic Multipass apex + wildcard routes under `{vm-name}.mp.localhost` and `*.{vm-name}.mp.localhost`.
- 2026-02-26: Added automatic Caddy startup on app launch and auto-reload on valid generated config changes.
- 2026-02-26: Added manual reload confirmation and rollback-safe config apply flow (backup, validate, restore on failure).
