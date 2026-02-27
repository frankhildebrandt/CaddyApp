# CaddyApp Feature Overview

This folder tracks feature-level progress for the macOS app that manages Caddy and localhost reverse proxies.

## Current goals

- Configure and manage Caddy on macOS.
- Manage reverse proxies for localhost subdomains.
- Make `tls internal` (AutoTLS) usable with an easier root certificate trust flow.
- Discover workloads from Multipass and Podman and propose proxy routes.
- Define on-demand container apps (Podman/Docker) that auto-start on first URL access and auto-stop after inactivity.
- Monitor Caddy releases and offer updates.
- Provide YAML-based custom app repositories that can be updated via web endpoints.
- Track implementation progress in feature documents.

## Feature index

| ID | Feature | Status | Document |
| --- | --- | --- | --- |
| F-010 | Caddy Installation & Updates | Done | `docs/features/010-caddy-installation-updates.md` |
| F-020 | Reverse Proxy for localhost subdomains | Done | `docs/features/020-reverse-proxy-localhost.md` |
| F-030 | AutoTLS & Root Certificate | Done | `docs/features/030-autotls-root-cert.md` |
| F-040 | Multipass & Podman Runtime Discovery | Done | `docs/features/040-runtime-discovery-multipass-podman.md` |
| F-050 | Caddy Release Monitoring | Done | `docs/features/050-release-monitoring.md` |
| F-060 | Feature Progress Tracking | Done | `docs/features/060-observability-progress.md` |
| F-070 | Menu Bar / Systray Integration | Done | `docs/features/070-menubar-systray.md` |
| F-080 | On-Demand Container Apps (Auto Start/Stop by URL Access) | Done | `docs/features/080-on-demand-container-apps.md` |
| F-090 | YAML App Repositories (Web-Updatable) | Done | `docs/features/090-yaml-app-repositories.md` |

## Workflow

- Update each feature document when implementation scope changes.
- Move checklist items from TODO to DONE as code lands.
- Keep status and acceptance criteria aligned with the actual app behavior.
