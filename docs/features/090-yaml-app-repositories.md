# F-090 YAML App Repositories (Web-Updatable)

## Status

- State: In Progress
- Owner: TBD
- Last Updated: 2026-02-27

## Goal

Custom-Apps sollen als YAML-Dateien definiert, ueber Web-Repositories verteilt und im laufenden Betrieb aus der App aktualisiert werden koennen.

## Scope

- In scope: YAML-Schema fuer On-Demand-App-Definitionen und einen App-Index.
- In scope: Repository-Index (`repositories.yaml`) mit mehreren eintragbaren Web-Repositories.
- In scope: Initiale YAML-Dateien fuer vorhandene Presets (Loki, Grafana, Kimai, Ephe).
- In scope: Bereitstellung des Repository-Feeds ueber GitHub Pages.
- Out of scope: Vollstaendige UI-Implementierung fuer Live-Editing im ersten Schritt.
- Out of scope: Signatur-/Trust-Modell fuer fremde Repositories (folgender Schritt).

## Acceptance Criteria

- [x] Es existiert ein versioniertes YAML-Format fuer App-Definitionen.
- [x] Es existiert ein App-Index (`apps/index.yaml`) mit URL-Referenzen auf einzelne App-YAMLs.
- [x] Es existiert ein Repository-Index (`repositories.yaml`) mit der GitHub-Pages-URL als erste Repo-URL.
- [x] Die bisherigen Preset-Apps liegen als einzelne YAML-Dateien vor.
- [x] GitHub Pages Deployment fuer den Feed ist im Repo konfiguriert.
- [ ] Die App kann Repository-Quellen in der UI verwalten (hinzufuegen/entfernen/priorisieren).
- [ ] Die App kann YAML-Dateien aus Repositories laden, validieren und in den lokalen Katalog uebernehmen.
- [ ] Die App bietet einen Web-Update-Flow fuer YAML-Inhalte inkl. Fehlerfeedback.

## Implementation Notes

- Erstes Schema orientiert sich direkt an den Feldern von `OnDemandAppDraft`.
- Feed-Struktur unter `docs/repository/`, damit GitHub Pages die Dateien statisch ausliefern kann.
- Repository-Index erlaubt spaetere Erweiterung auf mehrere Quellen und Prioritaeten.
- Fuer Produktionsbetrieb sind als naechster Schritt Schema-Validation und Vertrauensmodell (allowlist/signature) einzuplanen.

## Progress Log

- 2026-02-27: Feature-Dokument erstellt und initiales YAML-Repository-Format definiert.
- 2026-02-27: YAML-Dateien fuer Loki, Grafana, Kimai und Ephe angelegt.
- 2026-02-27: Repository-Index mit GitHub-Pages-URL als erster Quelle erstellt.
- 2026-02-27: GitHub-Pages-Workflow fuer `docs/` Deployment hinzugefuegt.
