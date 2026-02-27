# AGENTS.md

## Ziel

Dieses Dokument definiert verbindliche Regeln fuer Agenten/Automatisierung im Projekt `CaddyApp`.

## Arbeitsweise

1. Arbeite immer im bestehenden Projektstil (Swift, Makefile, Shell-Skripte).
2. Vor Abschluss einer Aenderung muss mindestens ein erfolgreicher Build laufen.
3. Build-Befehle bevorzugt ueber Makefile ausfuehren (`make build`, `make release`, `make check`).
4. Dokumentation bei aenderungsrelevanten Themen mitpflegen (`README.md`, `docs/PROJECT.md`, `docs/features/*`).
5. Existiert dieses Feature bereits, muss es aktualisiert werden, ansonsten wird ein neues Feature-Dokument angelegt.
6. Handelt es sich um ein neues Feature, muss automatisch ein neues Feature-Dokument angelegt werden.

## Verbindliche Commit-Regel

Nach jedem erfolgreichen Build, wenn Aenderungen vorhanden sind, muss automatisch ein Git-Commit erstellt werden.

Technische Umsetzung im Repo:

- `scripts/auto_commit_after_build.sh`
- aufgerufen von `make build` und `make release`

Der Commit soll:

- kurz beschrieben sein
- alle aktuellen Aenderungen enthalten (`git add -A`)
- nur dann entstehen, wenn die Working Tree nicht leer ist

Temporarer Override (nur bei Bedarf):

```bash
CADDYAPP_SKIP_AUTOCOMMIT=1 make build
```

## Verbindliche Feature-Dokumentationsregel

Bei neuen Features muss automatisch ein Feature-Dokument erzeugt werden.

Technische Umsetzung im Repo:

- `scripts/ensure_feature_doc.sh`
- wird durch `scripts/auto_commit_after_build.sh` vor dem Commit ausgefuehrt

Automatische Erzeugung erfolgt, wenn:

- Branch-Name `feat/...` oder `feature/...` entspricht, oder
- `CADDYAPP_FEATURE=1` gesetzt ist

Ausgabe:

- neue Datei unter `docs/features/NNN-<feature>.md`

Hinweise:

- Wenn bereits ein Feature-Dokument geaendert/angelegt wurde, wird kein zweites Auto-Dokument erstellt.
- Feature-Branches konsistent benennen, damit die Automatik sauber greift.

## Kurz-Checkliste fuer Agenten

1. Aenderung implementieren
2. `make build` (oder `make release`) ausfuehren
3. Pruefen, dass Auto-Commit erstellt wurde
4. Bei Feature-Branch pruefen, dass Feature-Dokument erzeugt wurde
