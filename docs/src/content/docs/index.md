---
title: CaddyApp Dokumentation
description: Übersicht, Einstieg und zentrale Arbeitsabläufe für CaddyApp.
template: splash
hero:
  title: CaddyApp für lokales Routing mit Caddy
  tagline: macOS-App für Caddy-Setup, `*.localhost`-Routing, Multipass-Services und On-Demand-Apps.
  actions:
    - text: Erste Schritte
      link: /guides/getting-started/
      icon: right-arrow
    - text: Service Discovery
      link: /guides/service-discovery/
      variant: secondary
---

import { Card, CardGrid } from "@astrojs/starlight/components";

<div class="hero">
  <p>CaddyApp bündelt Installation, Routing, Discovery, Preset-Synchronisation und Betriebsaufgaben für lokale Umgebungen in einer macOS-App. Diese Dokumentation ist für Anwender gedacht und beschreibt die produktiven Arbeitsabläufe statt interner Projektstände.</p>
</div>

<CardGrid stagger>
  <Card title="Schnell einsteigen" icon="rocket">
    Starte mit Build, Erstkonfiguration und dem Aufbau des Hauptfensters.
  </Card>
  <Card title="Service Discovery" icon="search">
    Verstehe, wie CaddyApp Laufzeitumgebungen erkennt und Routenvorschläge ableitet.
  </Card>
  <Card title="Multipass" icon="seti:vm">
    Nutze VM-Services mit Hostschema, YAML-Import und optionaler systemd-Steuerung.
  </Card>
  <Card title="On-Demand-Apps" icon="server">
    Starte Container oder Pods erst beim ersten Request und stoppe sie wieder nach Inaktivität.
  </Card>
</CardGrid>

## Was CaddyApp abdeckt

- Installation, Update-Hinweise und Runtime-Steuerung für Caddy auf macOS
- Generierung und sicheres Anwenden einer lokalen Caddy-Konfiguration
- `tls internal`-Workflows inklusive lokaler Zertifikats-/Trust-Hinweise
- Discovery für Multipass- und Podman-Workloads
- On-Demand-Apps mit Presets, Warm-up und Idle-Auto-Stop
- YAML-basierte Preset-Feeds über GitHub Pages
- Monitoring, Logs und Support-Einstieg direkt in der App

## Typische Arbeitsabläufe

<div class="quick-grid">
  <div class="quick-card">
    <strong>Routing einrichten</strong>
    <p>Definiere Hosts, Upstreams und Alias-Verhalten für `*.localhost` und optional `*.traefik.me`.</p>
  </div>
  <div class="quick-card">
    <strong>VM-Services publizieren</strong>
    <p>Importiere Services aus Multipass oder ergänze sie manuell für reproduzierbare Hosts.</p>
  </div>
  <div class="quick-card">
    <strong>Presets synchronisieren</strong>
    <p>Lade On-Demand-App-Definitionen aus einem YAML-Repository und füge sie direkt in die App ein.</p>
  </div>
  <div class="quick-card">
    <strong>Support finden</strong>
    <p>Öffne diese Dokumentation aus dem Support-Button der App oder mit <kbd>F1</kbd>.</p>
  </div>
</div>
