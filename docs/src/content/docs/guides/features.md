---
title: Feature-Überblick
description: Nutzerorientierte Übersicht über die wichtigsten Funktionen von CaddyApp.
---

## Kernfunktionen

### Caddy auf dem Mac verwalten

- erkennt bestehende Caddy-Installationen
- bevorzugt Homebrew, kann aber auch ein eigenes Binary verwalten
- unterstützt Start, Stop, Reload und Update-Prüfung

### Lokales Routing aufbauen

- erzeugt Host-spezifische Caddy-Sites für `*.localhost`
- nutzt `tls internal` für lokale Zertifikate
- kann zusätzliche `*.traefik.me`-Alias-Hosts generieren

### Laufzeiten erkennen

- erkennt Multipass- und Podman-Ziele
- leitet Hostvorschläge und Routing-Kandidaten daraus ab
- zeigt Runtime- und Diagnoseinformationen im Dashboard

### On-Demand-Apps betreiben

- startet Container oder Pods erst beim ersten Zugriff
- stoppt Einheiten nach einem konfigurierbaren Idle-Timeout
- bietet Presets, Logs, Shell-Zugriff und Event-Ansicht

### YAML-Presets verteilen

- lädt App-Definitionen aus GitHub-Pages-kompatiblen YAML-Repositories
- hält lokale Presets per manuellem oder automatischem Sync aktuell
- trennt Repository-Index, App-Index und einzelne App-Dokumente sauber

### Support und Monitoring

- zeigt Logs, Warnungen und Update-Hinweise direkt in der App
- öffnet die Dokumentation in einem eigenen Support-Fenster

## Für wen die App gedacht ist

- lokale Entwicklungsumgebungen auf macOS
- Testsysteme mit mehreren lokalen Hosts
- Multipass-basierte Services mit reproduzierbarer Host-Struktur
- Podman- oder Docker-basierte Tools, die nicht ständig laufen sollen
