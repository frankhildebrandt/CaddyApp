# CaddyApp

Bootstrap for a macOS SwiftUI app to configure and manage the Caddy web server with focus on localhost reverse proxies.

## Included in this bootstrap

- SwiftUI macOS dashboard (`swift run`)
- macOS menu bar (Systray) integration with dashboard reopen action
- Local Caddy install/version detection
- Automatic Caddy bootstrap install attempt (Homebrew first, direct download fallback) when missing
- Caddy release metadata lookup (GitHub API)
- Host-specific `*.localhost` reverse proxy Caddyfile preview with `tls internal` (no global wildcard site block)
- For `*.localhost` hosts, generated Caddyfile also adds `*.traefik.me` aliases for active macOS interface IPv4 addresses
- `Validate` / `Reload` automatically persist the current preview before executing Caddy commands
- `Reload Caddy` falls back to `caddy start` if no Caddy instance is currently running
- `Reload Caddy` retries via the macOS administrator dialog when elevated rights are required (no hidden CLI password prompt)
- Caddy starts automatically on app startup (when installed) using the generated config
- UI toggle shows the current Caddy runtime state and can start/stop Caddy
- Generated config changes are auto-validated and auto-reloaded when valid
- Custom Routes and On-Demand app changes are auto-saved and applied (manual save remains only for additional custom Caddyfile text)
- Caddy can be installed/updated without Homebrew (app-managed binary in `~/Library/Application Support/CaddyApp/bin/caddy`)
- Local Caddy CA root certificate path detection, auto-generation bootstrap, and trust guidance
- Root certificate trust action uses the macOS administrator dialog (no terminal password prompt required)
- Multipass / Podman discovery stubs (best effort)
- Automatic Multipass route: `{vm-name}.mp.localhost` (AutoTLS via `tls internal`)
- Dedicated Multipass tab page with runtime discovery and icon-based start/stop/systemd controls
- Multipass service config with per-service host/port/scheme, VM auto-start/stop, and systemd start/restart/stop controls
- Multipass YAML auto-config import from `/etc/caddy-app.yaml` (service URLs follow `*.<service>.<vm>.mp.localhost`)
- YAML-based app repository feed under `docs/repository/` (GitHub Pages ready)
- On-Demand preset picker supports web repository sources (`repositories.yaml` / `apps/index.yaml`) with update + import flow
- Feature progress documents in `docs/features/`

Details zum YAML-Aufbau fuer Multipass (`/etc/caddy-app.yaml`):
- `docs/features/040-runtime-discovery-multipass-podman.md` (Abschnitt `caddy-app.yaml Format`)

## Run

```bash
swift run
```

## Makefile

```bash
make help
make build
make open-app
make check
```

`make build` erzeugt ein vollstaendiges macOS-App-Bundle unter `_build/debug/CaddyApp.app` (Release: `_build/release/CaddyApp.app`).

## Dokumentation

- Projekt-Dokumentation: `docs/PROJECT.md`
- Feature-Dokumente: `docs/features/`
- YAML Repository Feed: `docs/repository/`
- Agent-Regeln: `AGENTS.md`

## Releases

> **Hinweis:** Der Build benötigt Swift >= 6.2.3. Ältere Versionen (z. B. 6.2.0) lösen einen Swift-Compiler-Assertion-Fehler aus (`LocalDiscriminator is set multiple times`).

Jeder GitHub Release loest automatisch einen CI-Build aus (`.github/workflows/release.yml`):

1. `swift build -c release` baut das Release-Binary auf einem macOS-Runner.
2. Das App-Bundle wird per `make_macos_app_bundle.sh` zusammengebaut.
3. `CaddyApp.zip` wird als Download-Asset an den GitHub Release angehaengt.

Die App-Version im `Info.plist` wird direkt aus dem Release-Tag uebernommen.

## Automatisierung

`make build` und `make release` erstellen keinen automatischen Git-Commit.
Der Commit wird nach erfolgreichem Build durch den Coding Agent mit kurzer, praegnanter Message ausgefuehrt.

Bei Feature-Branches (`feat/...`, `feature/...`) kann vor dem Agent-Commit automatisch ein Feature-Dokument unter `docs/features/` angelegt werden, falls noch keines geaendert wurde.

- Force-Flag: `CADDYAPP_FEATURE=1 make build`

## YAML Repository Feed

Die initialen Preset-Apps liegen als YAML-Dateien fuer Web-Repositories vor:

- `docs/repository/repositories.yaml` (Repository-Index)
- `docs/repository/apps/index.yaml` (App-Index)
- `docs/repository/apps/*.yaml` (einzelne App-Definitionen)

## Next engineering steps

1. Harden config apply flow with confirmations, backups, and rollback.
2. Add privilege-aware trust/install flow for local root certificate.
3. Add route approval UI for discovered Multipass/Podman workloads.
4. Add background release checks and user notifications.
