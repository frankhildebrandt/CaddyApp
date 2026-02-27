# F-040 Multipass & Podman Runtime Discovery

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-27

## Goal

Detect local workloads in Multipass and Podman and suggest reverse proxy routes automatically.

## Scope

- In scope: Query `multipass list --format json`.
- In scope: Query `podman ps --format json`.
- In scope: Normalize discovered targets into a shared runtime model.
- Out of scope: Editable route approval workflow.

## Acceptance Criteria

- [x] App attempts discovery for Multipass and Podman.
- [x] App normalizes results into shared runtime targets when JSON shape matches expected fields.
- [x] App derives an automatic route for Multipass VMs using `{vm-name}.mp.localhost`.
- [x] App lists discovered Multipass and Podman runtime targets in the shared runtime model.
- [x] Multipass target address inference probes common HTTP/HTTPS ports during bootstrap discovery.
- [x] App periodically refreshes runtime discovery in the background and auto-reloads Caddy when the generated config changes and validates successfully.

## Implementation Notes

- Bootstrap discovery is best-effort and tolerant of missing commands or JSON format drift.
- Podman port extraction is intentionally simple; more robust port mapping is needed.
- Multipass address inference probes common HTTP ports (`80`, `8080`, `8081`, `3000`, `8090`) first, then common HTTPS ports (`443`, `8443`) with certificate verification disabled for detection.
- Multipass VM names are sanitized into DNS labels before generating `{vm}.mp.localhost`.
- Editable approval flow for proposed routes remains future work and is tracked outside this bootstrap feature.
- Runtime discovery refresh is implemented as periodic background polling (best effort), not an event-driven runtime watcher.

## Progress Log

- 2026-02-26: Added initial shell-based discovery adapters and dashboard list.
- 2026-02-26: Added automatic Multipass apex + wildcard proxy routes (`{vm}.mp.localhost`, `*.{vm}.mp.localhost`) to generated Caddyfile.
- 2026-02-26: Added Multipass common-port probing for HTTP/HTTPS upstream detection (HTTPS probes ignore certificate errors).
- 2026-02-26: Marked bootstrap runtime discovery scope complete (`F-040` Done).
- 2026-02-26: Added background runtime polling (Multipass/Podman) and automatic Caddy reload when generated config changes.
- 2026-02-27: Removed automatic Multipass wildcard route generation to keep TLS issuance host-specific per subdomain.
