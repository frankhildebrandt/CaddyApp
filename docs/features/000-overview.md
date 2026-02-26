# CaddyApp Feature Overview

This folder tracks feature-level progress for the macOS app that manages Caddy and localhost reverse proxies.

## Current goals

- Configure and manage Caddy on macOS.
- Manage reverse proxies for `*.localhost`.
- Make `tls internal` (AutoTLS) usable with an easier root certificate trust flow.
- Discover workloads from Multipass and Podman and propose proxy routes.
- Monitor Caddy releases and offer updates.
- Track implementation progress in feature documents.

## Feature index

| ID | Feature | Status | Document |
| --- | --- | --- | --- |
| F-010 | Caddy Installation & Updates | Done | `docs/features/010-caddy-installation-updates.md` |
| F-020 | Reverse Proxy for `*.localhost` | Done | `docs/features/020-reverse-proxy-localhost.md` |
| F-030 | AutoTLS & Root Certificate | Done | `docs/features/030-autotls-root-cert.md` |
| F-040 | Multipass & Podman Runtime Discovery | Done | `docs/features/040-runtime-discovery-multipass-podman.md` |
| F-050 | Caddy Release Monitoring | Done | `docs/features/050-release-monitoring.md` |
| F-060 | Feature Progress Tracking | Done | `docs/features/060-observability-progress.md` |
| F-070 | Menu Bar / Systray Integration | Done | `docs/features/070-menubar-systray.md` |

## Workflow

- Update each feature document when implementation scope changes.
- Move checklist items from TODO to DONE as code lands.
- Keep status and acceptance criteria aligned with the actual app behavior.
