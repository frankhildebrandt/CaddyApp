# CaddyApp Project Documentation

## Purpose

Dieses Dokument beschreibt die interne Repo- und Prozesssicht. Die veröffentlichte Nutzerdokumentation wird mit Astro Starlight aus `docs/` gebaut und separat unter `docs/src/content/docs/` gepflegt.

## Tech Stack

- Swift 6 mit SwiftPM
- SwiftUI für die macOS-App
- Astro + Starlight für die veröffentlichte Dokumentation
- Makefile + Shell-Skripte für Build und Automatisierung

## Repo-Struktur

- `Sources/CaddyApp/` App-Code
- `Sources/CaddyApp/Views/Documentation/` eingebettetes Doku-Fenster mit `WKWebView`
- `Sources/CaddyApp/Services/Documentation/` zentraler Doku-Zugriff und Fenster-Routing
- `docs/src/content/docs/` veröffentlichte Starlight-Inhalte
- `docs/repository/` versionierter YAML-Feed für Repository-Presets
- `docs/features/` interne Feature-Dokumente
- `docs/scripts/` Build-Helfer für den Doku-Output

## Dokumentationsarchitektur

- `docs/` ist ein eigenständiges Astro-Projekt.
- Der statische Build landet unter `docs/dist/`.
- Nach dem Astro-Build wird `docs/repository/` nach `docs/dist/repository/` gespiegelt, damit die bestehenden Feed-URLs stabil bleiben.
- Die App lädt die veröffentlichte GitHub-Page im eigenen Dokumentationsfenster.

## Build und lokale Entwicklung

- `make build` baut die macOS-App
- `make release` baut das Release-Bundle
- `make production` baut die universelle Distributions-App inkl. ZIP
- `make dmg` erzeugt ein Installer-DMG mit Hintergrundbild und `Applications`-Link
- `make check` führt Build und Tests aus
- `make docs-install` installiert Doku-Abhängigkeiten
- `make docs-build` baut die Starlight-Dokumentation
- `make docs-dev` startet die lokale Doku-Entwicklung

## GitHub Actions

- `.github/workflows/release.yml` baut das macOS-Release und veröffentlicht zusätzlich die GitHub-Page aus `docs/dist/`
- `.github/workflows/pages.yml` dient als manueller Deploy-Pfad für dieselbe Astro-Dokumentation

## Agent- und Feature-Regeln

- `docs/features/` bleibt die interne Quelle für Feature-Status und Fortschritt.
- `scripts/ensure_feature_doc.sh` erzeugt auf Feature-Branches bei Bedarf ein neues internes Feature-Dokument.
- Nach erfolgreichem Build erstellt der Agent bei vorhandenem Diff einen Git-Commit.
