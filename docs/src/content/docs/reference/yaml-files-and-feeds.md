---
title: YAML-Dateien und Feeds
description: Referenz für GitHub-Pages-Feeds und VM-seitige YAML-Dateien.
---

## Zwei getrennte YAML-Welten

CaddyApp verwendet YAML an zwei unterschiedlichen Stellen:

1. **Repository-Feed für On-Demand-Presets**
2. **VM-seitige `/etc/caddy-app.yaml` für Multipass-Services**

Diese Formate sind getrennt und erfüllen unterschiedliche Aufgaben.

## Repository-Feed für Presets

Der veröffentlichte Feed liegt unter:

- `/repository/repositories.yaml`
- `/repository/apps/index.yaml`
- `/repository/apps/*.yaml`

### Aufbau

- `repositories.yaml` verweist auf einen oder mehrere App-Indizes
- `apps/index.yaml` listet konkrete App-Dokumente
- jede App-Datei beschreibt genau ein importierbares Preset

## App-Dokumente

Das YAML-Schema orientiert sich an den Feldern von `OnDemandAppDraft`. Wichtig sind insbesondere:

- Host und Zielport
- Runtime
- Startmodus
- Idle-Timeout
- `runArguments` oder `runSteps`

### Hinweis zu Startmodi

- `run_command` mit `runArguments` eignet sich für einfache Einzelschritte
- `run_command` mit `runSteps` ist die bevorzugte Form für mehrstufige Setups

## Multipass-Datei `/etc/caddy-app.yaml`

Diese Datei lebt in der VM und beschreibt importierbare Service-Definitionen für Multipass. Sie ist kein Ersatz für die Preset-Feeds und verwendet ein eigenes, kompakteres Format.

### Typische Felder

- `services`
- `name` oder `service`
- `port`
- `scheme`
- `health_path`
- `systemd_unit`
- `auto_start_vm`
- `auto_stop_vm`
- `auto_start_systemd`
- `auto_stop_systemd`
- `idle_timeout_seconds`

## Veröffentlichung

Die öffentliche Dokumentationssite und der YAML-Feed werden gemeinsam als statische GitHub-Page ausgeliefert. Dadurch bleiben die Feed-URLs stabil und die Dokumentation liegt unter derselben Basis-URL.
