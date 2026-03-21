---
title: Routing und Caddy
description: Wie CaddyApp Routen generiert, absichert und auf Caddy anwendet.
---

## Hostbasierte Routengenerierung

CaddyApp erzeugt für jede aktivierte Route einen eigenen Site-Block. Dadurch bleibt die Konfiguration host-spezifisch und lokale Zertifikate werden pro Host ausgestellt.

## Was automatisch passiert

- Vorschau der generierten Caddy-Konfiguration
- Schreiben in die von CaddyApp verwaltete Datei unter `~/Library/Application Support/CaddyApp/Caddyfile`
- Validierung vor dem Reload
- Rollback auf die letzte funktionierende Version bei Fehlern
- Fallback auf `caddy start`, wenn noch keine laufende Instanz existiert

## TLS und `tls internal`

- Für lokale Hosts wird `tls internal` genutzt.
- CaddyApp zeigt an, ob die lokale Root-CA vorhanden ist.
- Die App unterstützt den Trust-Workflow, damit Zertifikate im Browser akzeptiert werden.

## Alias-Hosts

Optional kann CaddyApp für `.localhost`-Hosts zusätzliche `traefik.me`-Alias-Adressen erzeugen. Das ist nützlich, wenn ein externer oder mobiler Zugriff für Tests benötigt wird, ohne das Grundschema der lokalen Hosts zu ändern.

## Wann Routing neu angewendet wird

- nach Änderungen an manuellen Routen
- nach Änderungen an On-Demand-Apps
- nach aktualisierter Runtime-Discovery, wenn sich die generierte Konfiguration ändert

## Empfehlung

Arbeite mit klaren, stabilen Hosts pro Dienst. Das erleichtert das TLS-Handling, Monitoring und das spätere Wiederverwenden in Presets oder VM-Konfigurationen.
