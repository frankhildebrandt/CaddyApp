---
title: Erste Schritte
description: Build, Start und erster produktiver Einsatz von CaddyApp.
---

## Voraussetzungen

- macOS 14 oder neuer
- Swift 6.x für lokale Entwicklung
- Optional Homebrew für die bevorzugte Caddy-Installation
- Optional Multipass, Podman oder Docker für Discovery- und On-Demand-Workflows

## Lokal starten

```bash
make build
make open-app
```

Alternativ:

```bash
make run
```

## Aufbau der App

- **Übersicht** zeigt Runtime- und Repositorystatus.
- **Setup & Status** bündelt Installation, TLS und Systemzustand.
- **Routing** verwaltet generierte Caddy-Routen.
- **Services** konzentriert sich auf Multipass-VMs und deren Service-Definitionen.
- **Apps** bündelt On-Demand-Apps und Presets.
- **Monitoring** zeigt Logs, Runtime-Hinweise und Betriebsdetails.

## Typischer Erst-Setup

1. Caddy installieren oder den vorhandenen Installationsstatus prüfen.
2. Lokales Vertrauen für `tls internal` herstellen.
3. Erste Route oder einen erkannten Service übernehmen.
4. Falls benötigt Multipass- oder On-Demand-Konfiguration ergänzen.
5. Konfiguration anwenden und die Hostnamen im Browser testen.

## Support und Dokumentation

- Der **Support**-Button in der Sidebar öffnet diese Dokumentation direkt in einem App-Fenster.
- Derselbe Einstieg ist in der App auch über <kbd>F1</kbd> erreichbar.
- Für Release-Artefakte und Quellcode dient das GitHub-Repository als primäre Quelle.
