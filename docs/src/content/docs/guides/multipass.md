---
title: Multipass-VMs
description: Nutzung von Multipass-Services mit Hostschema, YAML und Runtime-Steuerung.
---

## Hostschema

Für Services innerhalb einer VM verwendet CaddyApp standardmäßig:

- `<service>.<vm>.mp.localhost`
- zusätzlich Wildcard-Routing für `*.<service>.<vm>.mp.localhost`

Für VM-Apex-Ziele kann außerdem `<vm>.mp.localhost` genutzt werden.

## Was pro Service konfigurierbar ist

- Zielport
- `http` oder `https`
- Health-Pfad
- Auto-Start und Auto-Stop der VM
- optionale systemd-Unit
- Auto-Start und Auto-Stop der systemd-Unit
- Idle-Timeout

## YAML-Import aus der VM

Wenn eine laufende VM die Datei `/etc/caddy-app.yaml` enthält, kann CaddyApp daraus Services importieren. Die importierten Einträge werden als YAML-gesteuert behandelt.

### Erwartete Felder

- `name` oder `service`
- `port`
- optional `scheme`
- optional `health_path`
- optional `systemd`, `systemd_unit` oder `unit`
- optionale Auto-Flags für VM und systemd
- optional `idle_timeout_seconds`

## Beispiel

```yaml
services:
  - name: grafana
    port: 3000
    scheme: http
    health_path: /login
    systemd_unit: grafana-server.service
    auto_start_vm: true
    auto_stop_vm: true
    auto_start_systemd: true
    auto_stop_systemd: false
    idle_timeout_seconds: 900
```

## Laufzeitverhalten

- Ist die VM gestoppt, kann CaddyApp sie beim Zugriff best effort starten.
- Für `https`-Services akzeptiert der interne Proxy auch self-signed Ziele, damit lokale VM-Dienste erreichbar bleiben.
- Wenn der Dienst erreichbar ist, bevorzugt CaddyApp die direkte VM-IP als Upstream und nutzt den App-internen Gateway-Pfad nur noch als Fallback für kalte Starts oder vorübergehend nicht erreichbare Ziele.

## Bekannte Grenzen

- YAML-Import startet keine gestoppten VMs nur zum Einlesen der Datei.
- Discovery und Import hängen von verfügbaren Multipass-CLI-Kommandos ab.
