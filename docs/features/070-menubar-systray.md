# F-070 Menu Bar / Systray Integration

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-26

## Goal

Die App soll in der macOS-Menueleiste (Systray) verfuegbar bleiben und sich dorthin minimieren lassen.

## Scope

- In scope: `MenuBarExtra` mit Statusanzeige und Aktionen.
- In scope: Hauptfenster ausblenden und spaeter aus der Menueleiste wieder oeffnen.
- In scope: App nicht beenden beim Schliessen des letzten Fensters.
- Out of scope: Vollstaendig docklose App / Launch-at-login im Bootstrap.

## Acceptance Criteria

- [x] App zeigt ein Menueleisten-Icon.
- [x] Dashboard kann aus der Menueleiste geoeffnet werden.
- [x] App beendet sich nicht automatisch beim Schliessen des letzten Fensters.
- [x] Im Dashboard gibt es eine Aktion zum Minimieren in die Menueleiste.
- [x] Optional konfigurierbar: Beim Schliessen immer statt Schliessen nur verstecken.

## Implementation Notes

- Implementiert mit SwiftUI `MenuBarExtra`.
- Fensteroeffnung nutzt `openWindow(id:)`.
- Das Verstecken erfolgt aktuell ueber `NSApp.hide(nil)`.
- Optionales Close-Verhalten wird per `UserDefaults` / `@AppStorage` konfiguriert.
- Close-Intercept des Hauptfensters erfolgt ueber `NSWindowDelegate.windowShouldClose`.

## Progress Log

- 2026-02-26: MenuBarExtra hinzugefuegt und Dashboard-Button zum Ausblenden eingebaut.
- 2026-02-26: Option "Schliessen versteckt" im Dashboard hinzugefuegt und Close-Intercept fuer Hauptfenster aktiviert.
