---
title: Service Discovery
description: Discovery für Multipass- und Container-Workloads in CaddyApp.
---

## Überblick

CaddyApp versucht lokale Workloads best effort zu erkennen und daraus nutzbare Routing-Kandidaten abzuleiten. Discovery ist ein Betriebshelfer, kein verpflichtender Konfigurationspfad.

## Erkannte Quellen

- **Multipass** über `multipass list --format json`
- **Podman** über `podman ps --format json`

## Was die App daraus macht

- normalisiert gefundene Ziele in ein gemeinsames Runtime-Modell
- zeigt erkannte Ziele im Dashboard
- leitet Default-Hosts und Upstream-Ziele ab
- aktualisiert Discovery zyklisch im Hintergrund

## Multipass gegenüber allgemeinen Runtime-Zielen

### Allgemeine Runtime-Ziele

- dienen vor allem als sichtbare Discovery- und Diagnosequelle
- sind nützlich für Routing-Vorschläge und Monitoring

### Multipass-Services

- gehen einen Schritt weiter als reine Discovery
- können persistiert konfiguriert werden
- unterstützen Hostschema, Auto-Start, Auto-Stop und systemd-Aktionen
- können per `/etc/caddy-app.yaml` auf der VM teilautomatisch importiert werden

## Adress- und Portermittlung

- HTTP-Ports werden bevorzugt direkt geprüft
- HTTPS-Ziele werden gesondert behandelt
- falls Host-seitige Erkennung nicht reicht, kann die App VM-intern nach Listenern suchen

## Grenzen

- Discovery ist absichtlich fehlertolerant und nicht event-getrieben
- fehlende Tools oder geänderte CLI-Ausgaben können die Erkennung einschränken
- Discovery ersetzt keine saubere fachliche Konfiguration für produktivere lokale Setups
