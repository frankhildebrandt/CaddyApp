# 110 Modern AppConfig Flow

## Status

- implemented

## Summary

This feature introduces the first cohesive modernization step for CaddyApp:

- task-oriented main navigation
- consolidated `AppConfig` persistence with legacy migration
- automatic GitHub Pages preset sync
- centralized dialog presentation
- guided Multipass service creation

## Implementation Notes

- `AppConfig` replaces the old single-purpose config model and stores app behavior, routing, repository sync, routes, apps, services, and repositories.
- `AppConfigStore` loads the new format and transparently migrates legacy `CustomConfigSettings`.
- `DashboardViewModel` now persists feed-sync and general settings together with route/app/service changes.
- GitHub Pages preset repositories can auto-sync on a configurable interval.
- The main shell is organized around workflows:
  - Overview
  - Setup & Status
  - Routing
  - Services
  - Apps
  - Monitoring

## UX Notes

- Menu bar content was reduced to user-relevant status and actions.
- Long explanatory copy was reduced; secondary details moved into captions or tooltips.
- Multipass service setup now starts with an assistant row that proposes host and defaults.

## Follow-up Candidates

- split `DashboardViewModel` further into dedicated feature stores
- extend assistant guidance into routing and diagnostics flows
- add explicit offline cache fallback for remote presets
