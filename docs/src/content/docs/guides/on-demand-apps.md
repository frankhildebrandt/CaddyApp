---
title: On-Demand-Apps
description: Container- und Pod-Workloads mit URL-getriggertem Start.
---

## Ziel

On-Demand-Apps laufen nicht dauerhaft. Stattdessen startet CaddyApp den konfigurierten Container oder Pod erst beim ersten Zugriff auf die zugehörige URL und stoppt ihn wieder nach Inaktivität.

## Unterstützte Laufzeiten

- Podman
- Docker

## Wichtige Bausteine einer Definition

- Anzeigename
- Host
- Zielhost und Zielport
- Runtime und Unit-Typ
- Startmodus
- Run-Argumente oder sequenzielle Run-Schritte
- Idle-Timeout

## Verhalten beim ersten Request

1. Der Request trifft auf den konfigurierten Host.
2. Caddy versucht den direkten Upstream.
3. Ist das Ziel noch nicht erreichbar, übernimmt der lokale Gateway-Fallback.
4. CaddyApp startet die Runtime-Einheit und wartet auf das Warm-up.
5. Sobald der Dienst gesund ist, läuft der Verkehr direkt zum Backend.

## Idle-Auto-Stop

- Zugriffe werden über Caddy-Access-Logs verfolgt.
- Bleibt ein Dienst länger als das konfigurierte Timeout ungenutzt, stoppt CaddyApp die zugehörige Einheit.
- Wiederholte Zugriffe verlängern das Zeitfenster automatisch.

## Presets und YAML-Feeds

Die App enthält lokale Presets und kann zusätzlich YAML-basierte Presets aus GitHub Pages laden. Typische mitgelieferte Beispiele sind Loki, Grafana, Kimai, Penpot, Ephe und authentik.

## Bedienung in der App

- Preset-Picker zum Anlegen neuer Apps
- Konfigurationsansicht für Host, Runtime und Startverhalten
- Host-Logs
- Container- oder Pod-Logs
- eingebettete Shell
- Event-Log für Start/Stop/Warm-up-Ereignisse

## Empfehlung

Nutze `runSteps` für komplexe Pod- oder Multi-Container-Setups. Dadurch bleibt der Startablauf nachvollziehbar und robuster als mit langen Shell-Ketten.
