# F-080 On-Demand Container Apps (Auto Start/Stop by URL Access)

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-27

## Goal

Allow users to define Podman/Docker apps that start automatically when their configured URL is accessed and stop automatically after a configurable inactivity timeout.

## Scope

- In scope: Define apps backed by Podman or Docker containers/pods.
- In scope: Map each app to one or more URLs handled by CaddyApp/Caddy.
- In scope: Auto-start app on incoming request to the configured URL.
- In scope: Auto-stop app/container/pod after a user-defined period without requests.
- In scope: Sensible default app templates for Loki, Grafana, Kimai, and Ephe (`https://github.com/unvalley/ephe`).
- Out of scope: Full container image build pipeline or compose authoring UI (initial version may use presets + simple runtime args).
- Out of scope: Multi-node orchestration (Kubernetes, Swarm, Nomad).

## Acceptance Criteria

- [x] User can create an app definition with runtime (`podman` or `docker`), image/container start command, URL/host, target port, and idle timeout.
- [x] First request to the app URL triggers best-effort start of the corresponding container or pod before proxying traffic.
- [x] App is stopped automatically when no requests were received for the configured timeout window.
- [x] Repeated requests within the timeout window keep the app running (idle timer extends/reset on access).
- [x] Default templates for Loki, Grafana, Kimai, and Ephe can be added from the UI with editable values.
- [x] App state (stopped / starting / running / stopping / error) is visible in the app UI.
- [x] Failures to start/stop are surfaced to the user with actionable logs or error messages.
- [x] Deleting an on-demand app also removes the associated runtime unit (container/pod).
- [x] Each on-demand app card exposes sub-tabs for config editing, host-filtered logs, container/pod logs, shell access, and event logs.

## Implementation Notes

- Request-triggered start likely needs a small activation gate in front of the reverse proxy path to avoid racing concurrent requests.
- Idle timeout should be based on last successful access time recorded by the app/router layer, not only process state.
- Consider a warm-up/health-check step before forwarding the first request (especially for Grafana/Kimai startup latency).
- Podman and Docker command execution should share a normalized runtime adapter (`start`, `stop`, `status`, `logs`).
- Default app templates should include container image, exposed port, suggested host/path, and persistence volume hints.
- Ephe template source: `https://github.com/unvalley/ephe`.
- Implementation uses a local HTTP gateway (`127.0.0.1:49215`) that Caddy proxies to for on-demand hosts.
- Runtime tab supports manual start/stop controls in addition to URL-triggered activation.
- Logging tab records CLI commands plus start/stop and warm-up events for debugging.
- On-demand app cards include per-app observability/ops sub-tabs (Config, Host-Log, Container/Pod-Log, Shell, Eventlog).
- Current limitation: no chunked request-body forwarding yet.

## Progress Log

- 2026-02-26: Created feature doc for URL-triggered on-demand Podman/Docker apps with idle auto-stop and default templates (Loki, Grafana, Kimai, Ephe).
- 2026-02-26: Implemented MVP on-demand app definitions, presets, Caddy route generation via local gateway, runtime start/stop logic (Docker/Podman), health warm-up, and idle auto-stop.
- 2026-02-26: Added logging tab (CLI + start/stop events), manual on-demand app start/stop controls, runtime state refresh, and run-command fallback to existing container start after idle stop.
- 2026-02-26: Added WebSocket upgrade support in the on-demand gateway via bidirectional TCP tunnel after HTTP Upgrade handshake forwarding.
- 2026-02-27: Added runtime cleanup on app deletion (`container/pod rm -f`) with tolerant handling when unit is already missing.
- 2026-02-27: Added per-app sub-tabs for config, host log filtering, container/pod logs, interactive shell launch, and event-log view.
- 2026-02-27: Refined On-Demand UI to an overview layout (app list + single tabbed detail view) instead of per-card tabs.
- 2026-02-27: Refined further to full-view switching: app overview list as default, then full detail/tab view with explicit back-to-list action.
- 2026-02-27: Updated detail action bar to icon-based start/stop controls and removed direct logs action; shell tab now opens an interactive container shell automatically on tab entry.
- 2026-02-27: Replaced external Terminal launch with an embedded in-app shell session inside the Shell tab (live stdin/stdout in the app UI).
- 2026-02-27: Gateway adjusted to keep returning the on-demand status/waiting page while an app is still not reachable during warm-up instead of returning a hard 502 text error.
- 2026-02-27: Gateway proxy now forces identity encoding upstream and strips forwarded `Content-Encoding` to avoid browser `ERR_CONTENT_DECODING_FAILED` on proxied app responses (e.g. `ephe.localhost`).
