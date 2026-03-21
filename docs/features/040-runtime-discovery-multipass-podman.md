# F-040 Multipass & Podman Runtime Discovery

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-03-21

## Goal

Detect local workloads in Multipass and Podman and suggest reverse proxy routes automatically.

## Scope

- In scope: Query `multipass list --format json`.
- In scope: Query `podman ps --format json`.
- In scope: Normalize discovered targets into a shared runtime model.
- In scope: Multipass service configuration for host/port/scheme with generated `*.<service>.<vm>.mp.localhost` routes.
- In scope: Multipass VM auto-start/auto-stop behavior on gateway access (on-demand style).
- In scope: systemd unit monitoring and controls (`start`/`restart`/`stop`) per Multipass service.
- In scope: YAML auto-config import from VM file `/etc/caddy-app.yaml`.
- Out of scope: Editable route approval workflow.

## Acceptance Criteria

- [x] App attempts discovery for Multipass and Podman.
- [x] App normalizes results into shared runtime targets when JSON shape matches expected fields.
- [x] App derives an automatic route for Multipass VMs using `{vm-name}.mp.localhost`.
- [x] App generates a default wildcard alias route for Multipass VMs using `*.{vm-name}.mp.localhost`.
- [x] App lists discovered Multipass and Podman runtime targets in the shared runtime model.
- [x] Multipass target address inference probes common HTTP/HTTPS ports during bootstrap discovery.
- [x] App periodically refreshes runtime discovery in the background and auto-reloads Caddy when the generated config changes and validates successfully.
- [x] App supports per-service Multipass routing config (host/port/scheme/health/systemd/auto-start-stop) persisted in custom config.
- [x] App generates service routes with wildcard host support (`*.<service>.<vm>.mp.localhost`) via the on-demand gateway.
- [x] App can auto-start stopped Multipass VMs and optionally auto-start configured systemd units before proxying.
- [x] App can auto-stop Multipass VMs after idle timeout (optional, per service) and optionally stop systemd units.
- [x] App imports service definitions from `/etc/caddy-app.yaml` on Multipass VMs and marks them as YAML-managed.
- [x] Multipass management was moved into a dedicated UI tab page, while Runtime focuses on non-Multipass targets.
- [x] Multipass UI renders VM-specific cards with VM runtime controls (`start` / `stop` / `force-stop`) and per-card service add action.

## Implementation Notes

- Bootstrap discovery is best-effort and tolerant of missing commands or JSON format drift.
- Podman port extraction is intentionally simple; more robust port mapping is needed.
- Multipass address inference probes common HTTP ports (`8080`, `80`, `8081`, `3000`, `8090`) first, then common HTTPS ports (`443`, `8443`) with certificate verification disabled for detection.
- Port probing is executed in-app: HTTP ports are checked via direct TCP connect (`Network` framework), HTTPS ports via `URLSession` with optional insecure TLS for detection.
- If host-side probing cannot determine a port, the app falls back to VM-internal listener detection (`multipass exec` + `ss`/`netstat`) before using a static default.
- Multipass VM names are sanitized into DNS labels before generating `{vm}.mp.localhost`.
- Editable approval flow for proposed routes remains future work and is tracked outside this bootstrap feature.
- Runtime discovery refresh is implemented as periodic background polling (best effort), not an event-driven runtime watcher.
- Multipass service routing prefers the currently discovered VM IP directly and uses the existing on-demand gateway port (`127.0.0.1:49215`) only as a fallback when the service endpoint is not reachable yet, so warm-up remains intact without keeping the app process in the steady-state hot path.
- YAML import is intentionally minimal and expects a `services:` list with per-item fields like `name/service`, `port`, optional `scheme`, `systemd(_unit)`, and auto flags.
- YAML import only runs `multipass exec` against VMs that are already in `running` state, so app startup does not implicitly start stopped VMs.
- Runtime-discovery shell calls now use hard timeouts so unavailable or wedged `multipass`/`podman` CLIs degrade to "no targets found" instead of stalling app startup indefinitely.
- YAML-discovered Multipass services are now listed separately and only enter the generated Caddy routing after the user opens the service detail view and saves the configuration explicitly.

## caddy-app.yaml Format

Dateipfad auf der VM:
- `/etc/caddy-app.yaml`

Top-Level:
- `services` (Pflicht): Liste von Service-Eintraegen

Service-Felder:
- `name` oder `service` (Pflicht): Service-Name
- `port` (Pflicht): Ziel-Port in der VM
- `scheme` (optional): `http` (Default) oder `https`
- `health_path` (optional): Health-Pfad, Default `/`
- `systemd`, `systemd_unit` oder `unit` (optional): systemd Unit-Name, z. B. `nginx.service`
- `enabled` (optional): `true`/`false`, Default `true`
- `auto_start_vm` (optional): `true`/`false`, Default `true`
- `auto_stop_vm` (optional): `true`/`false`, Default `true`
- `auto_start_systemd` (optional): `true`/`false`, Default `true`
- `auto_stop_systemd` (optional): `true`/`false`, Default `false`
- `idle_timeout_seconds` (optional): Idle-Timeout in Sekunden, Default `600`

Host- und URL-Regel:
- Host wird aus VM-Name + Service-Name automatisch erzeugt.
- Format: `<service>.<vm>.mp.localhost`
- Zusätzlich wird Wildcard-Routing erzeugt: `*.<service>.<vm>.mp.localhost`

Beispiel:

```yaml
services:
  - name: grafana
    port: 3000
    scheme: http
    health_path: /login
    systemd_unit: grafana-server.service
    enabled: true
    auto_start_vm: true
    auto_stop_vm: true
    auto_start_systemd: true
    auto_stop_systemd: false
    idle_timeout_seconds: 900

  - service: api
    port: 8443
    scheme: https
    health_path: /health
    enabled: true
```

## Progress Log

- 2026-02-26: Added initial shell-based discovery adapters and dashboard list.
- 2026-02-26: Added automatic Multipass apex + wildcard proxy routes (`{vm}.mp.localhost`, `*.{vm}.mp.localhost`) to generated Caddyfile.
- 2026-02-26: Added Multipass common-port probing for HTTP/HTTPS upstream detection (HTTPS probes ignore certificate errors).
- 2026-02-26: Marked bootstrap runtime discovery scope complete (`F-040` Done).
- 2026-02-26: Added background runtime polling (Multipass/Podman) and automatic Caddy reload when generated config changes.
- 2026-02-27: Removed automatic Multipass wildcard route generation to keep TLS issuance host-specific per subdomain.
- 2026-02-27: Added Multipass service configuration UI (host/port/scheme/auto-start-stop/systemd), runtime controls, and status monitoring.
- 2026-02-27: Added wildcard service route generation (`*.<service>.<vm>.mp.localhost`) for YAML/manual Multipass service definitions.
- 2026-02-27: Added YAML auto-import from VM `/etc/caddy-app.yaml` into persistent app config (YAML-managed entries).
- 2026-02-27: Prevented startup side-effect where YAML import could wake stopped VMs; importer now skips non-running VMs.
- 2026-03-02: Split Multipass UI into its own tab page and moved runtime-level Multipass controls/discovery out of the generic Runtime tab.
- 2026-03-02: Reworked Multipass tab to VM cards, added direct VM runtime controls (including force-stop), and moved "Service hinzufügen" into each VM card.
- 2026-03-02: Gateway proxy now accepts self-signed TLS certificates for Multipass services configured with `scheme: https`, avoiding spurious 502 errors.
- 2026-03-02: Re-enabled default wildcard alias route generation for VM apex hosts (`*.{vm}.mp.localhost`) in generated Caddy config.
- 2026-03-02: Replaced shell-based `curl` probing for Multipass VM port detection with app-native HTTP requests.
- 2026-03-03: Hardened Multipass HTTP port detection by switching to direct TCP probing (proxy-independent), so active ports like `8080` are detected reliably when `80` is closed.
- 2026-03-03: Added VM-internal HTTP listener fallback (`ss`/`netstat` via `multipass exec`) to prevent false fallback to port `80` when host-side probes cannot reach guest services.
- 2026-03-21: Multipass service routes now use the discovered VM IP as direct Caddy upstream when available and keep the in-app gateway only as fallback for cold starts/unreachable targets.
- 2026-03-21: Added hard timeouts for startup/runtime discovery shell commands so hung `multipass` or `podman` calls no longer leave the app loading forever.
- 2026-03-21: Changed Multipass YAML discovery so services are listed first and only become part of the saved routing config after explicit confirmation in the detail view.
