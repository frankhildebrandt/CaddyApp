# CaddyApp

CaddyApp ist eine macOS-Desktop-App (SwiftUI) zur lokalen Verwaltung von [Caddy](https://caddyserver.com/).
Der Schwerpunkt liegt auf `*.localhost`-Reverse-Proxy-Workflows, automatisierter Caddy-Konfiguration und On-Demand-App-Routing.

## Ziel des Projekts

- Caddy auf macOS einfach installieren, aktualisieren und steuern.
- Lokale Reverse-Proxies fuer Entwicklungs- und Test-Setups verwalten.
- AutoTLS (`tls internal`) inkl. Root-CA-Trust-Flow nutzbar machen.
- Multipass-/Podman-Workloads erkennen und als Routen integrieren.
- On-Demand-Apps per URL starten und bei Inaktivitaet wieder stoppen.

## Funktionsumfang

- SwiftUI-App mit task-orientierter Hauptnavigation und Menubar/Systray-Integration
- App-Settings via macOS-Standard `Apple-,` sowie globales App-Menue (`CaddyApp`)
- Konfigurationsverwaltung als zentrale `AppConfig` in den CaddyApp Settings
- Automatischer GH-Pages-Feed-Sync fuer On-Demand-Presets
- Caddy-Erkennung inkl. Install-/Update-Flow
  - Homebrew zuerst
  - Fallback auf app-verwaltetes Binary unter
    `~/Library/Application Support/CaddyApp/bin/caddy`
- Caddy-Release-Monitoring (GitHub API)
- Generierte Caddy-Konfiguration fuer Host-Routen auf `*.localhost`
- Optional zuschaltbare `*.traefik.me`-Alias-Hosts pro `*.localhost`-Route
- Auto-Persistenz + Auto-Validate + Auto-Reload bei gueltigen Aenderungen
- Caddy-Runtime-Steuerung (Start/Stop/Reload) inkl. Fallback-Start
- Auto-Reparatur fuer Homebrew-Service, wenn `/opt/homebrew/etc/Caddyfile` fehlt (inkl. Service-Restart)
- Auto-Konsolidierung mehrerer laufender Caddy-Prozesse auf eine Instanz (bevorzugt Homebrew-Service)
- Privilegierte Aktionen ueber macOS-Admin-Dialog (kein versteckter Passwortprompt)
- Root-CA-Erkennung und Trust-Unterstuetzung fuer lokale Zertifikate
- Multipass-Service-Erkennung und -Steuerung (Start/Stop/force-stop)
- Multipass-Import aus `/etc/caddy-app.yaml`
- YAML-basierte Web-Repositories fuer On-Demand-App-Presets
- Gemeinsamer interner Scheduler fuer Polling-, Debounce- und Maintenance-Jobs
- Asynchrone Command-Ausfuehrung fuer UI-relevante Aktionen (Caddy/TLS/Update/Logs)
- Skeleton-Loading fuer Hauptzustand und Inline-Loading-Indikatoren statt Spinner-Fokus

## Voraussetzungen

- macOS 14 oder neuer
- Swift 6.x (SwiftPM)
- Optional:
  - Homebrew (fuer bevorzugte Caddy-Installation)
  - Multipass / Podman (fuer Runtime-Discovery-Features)

## Schnellstart

```bash
make build
make open-app
```

Alternativ direkt starten:

```bash
make run
```

## Build und Entwicklung

Wichtige Make-Targets:

```bash
make help      # Targets anzeigen
make build     # Debug-Build + .app-Bundle
make release   # Release-Build + .app-Bundle
make run       # App ueber SwiftPM starten
make test      # Tests ausfuehren
make check     # build + test
make docs      # Feature-Dokumente auflisten
```

Build-Artefakte:

- Debug: `_build/debug/CaddyApp.app`
- Release: `_build/release/CaddyApp.app`

## Projektstruktur

- `Sources/CaddyApp/Views/AppShell/` - Hauptfenster-Shell (Header, Sidebar, Main-Layout)
- `Sources/CaddyApp/Views/Tabs/` - task-orientierte Arbeitsbereiche (Uebersicht/Setup/Routing/Services/Apps/Monitoring)
- `Sources/CaddyApp/Views/Settings/` - Settings-Root + Pane-Views
- `Sources/CaddyApp/Views/OnDemand/` - On-Demand-Feature-Komponenten
- `Sources/CaddyApp/Views/Shared/` - Wiederverwendbare UI-Bausteine
- `Sources/CaddyApp/ViewModels/` - UI-State und Orchestrierung
- `Sources/CaddyApp/ViewModels/Features/` - Feature-spezifische ViewModels
- `Sources/CaddyApp/Services/` - Caddy-, Runtime- und Systemintegration
- `Sources/CaddyApp/Models/` - Domain-Modelle (one-type-per-file)
  - `Models/Config/`, `Models/Routing/`, `Models/OnDemand/`, `Models/Multipass/`
  - `Models/Repository/`, `Models/Caddy/`, `Models/TLS/`, `Models/Setup/`, `Models/Dashboard/`, `Models/Features/`
- `docs/features/` - Feature-Status und Fortschrittsdokumente
- `docs/repository/` - YAML-Feeds fuer Web-Repositories
- `scripts/` - Build- und Automatisierungs-Skripte
- `assets/` - App- und Systray-Grafiken

## YAML-Repository-Feed

Der initiale Repository-Feed liegt unter:

- `docs/repository/repositories.yaml`
- `docs/repository/apps/index.yaml`
- `docs/repository/apps/*.yaml`

Dieser Bereich ist fuer GitHub Pages vorgesehen und dient als Quelle fuer importierbare On-Demand-App-Definitionen.

## Multipass-Konfiguration

Optional kann pro VM eine Konfiguration aus `/etc/caddy-app.yaml` importiert werden.
Typische Inhalte:

- Service-Name, Port, Scheme (`http`/`https`)
- Host-/Wildcard-Routing (z. B. `*.<service>.<vm>.mp.localhost`)
- VM Auto-Start/Auto-Stop
- systemd-Steuerung (`start`, `restart`, `stop`)

Details siehe:
`docs/features/040-runtime-discovery-multipass-podman.md`.

## Releases

GitHub-Releases triggern den Build-Workflow in `.github/workflows/release.yml`.
Dabei wird ein Release-Build erstellt, als macOS-App gebuendelt und als ZIP-Artefakt angehaengt.
Der Release-Build wird als Universal-Binary (`arm64` + `x86_64`) erzeugt.

### Release-App lokal starten (Download von GitHub)

Nach dem Entpacken kann macOS die App beim ersten Start blockieren (Gatekeeper/Quarantine).
Falls die App nicht startet:

```bash
xattr -dr com.apple.quarantine CaddyApp.app
open CaddyApp.app
```

Optional zur Architektur-Pruefung:

```bash
file CaddyApp.app/Contents/MacOS/CaddyApp
```

## Dokumentation

- Projektueberblick: `docs/PROJECT.md`
- Feature-Index: `docs/features/000-overview.md`
- Feature-Details: `docs/features/*.md`
- Repository-Feed-Doku: `docs/repository/README.md`
- Agent-Regeln: `AGENTS.md`

## Architektur-Hinweis (Model Refactor)

- Business-Logik (Validierung, Normalisierung, Mapping/Factory-Regeln) liegt in `Models/**`.
- `ViewModels` halten UI-Zustand und orchestrieren Services.
- `Services` kapseln IO/Systemintegration (Shell, Netzwerk, Filesystem) und vermeiden fachliche Duplikation.
- Persistierte Einstellungen laufen ueber `AppConfig`; Legacy-`CustomConfigSettings` werden beim Laden migriert.
