# CaddyApp Project Documentation

## Purpose

CaddyApp is a macOS SwiftUI desktop app for local Caddy setup and operation.
The focus is localhost reverse-proxy workflows, automated Caddy runtime management, and safe operational actions for desktop users.

## Tech Stack

- Language: Swift 6 (Swift Package Manager)
- UI: SwiftUI (macOS target)
- Build tooling: `Makefile` + shell scripts
- Build artifacts: `_build/debug/CaddyApp.app`, `_build/release/CaddyApp.app`

## Runtime Architecture Updates

- Shared internal scheduler (`InternalScheduler`) for recurring and debounced jobs.
- Async wrappers for command-heavy services to keep UI interaction responsive.
- Dashboard runtime polling interval tuned to reduce idle CPU pressure.
- Loading UX standardized with skeleton placeholders and inline skeleton activity states.
- Global app menu plus native macOS settings window (`Apple-,`) added.
- Main window now uses `AppShellView` with dedicated shell components (`AppHeaderView`, `AppSidebarView`) and per-feature detail views.
- Settings are decoupled into `SettingsRootView` with pane views (`General`, `On-Demand`, `Services`, `Custom Config`) instead of `ContentView` extensions.
- On-Demand, Multipass, and Settings feature state is segmented into feature view models under `ViewModels/Features/*`.

## Repository Structure

- `Sources/CaddyApp/`
- `Sources/CaddyApp/Views/`: SwiftUI views
- `Sources/CaddyApp/Views/AppShell/`: shell layout and window/menu entry views
- `Sources/CaddyApp/Views/Tabs/`: main dashboard tab views
- `Sources/CaddyApp/Views/Settings/`: settings root and pane views
- `Sources/CaddyApp/Views/OnDemand/`: on-demand feature subviews
- `Sources/CaddyApp/Views/Shared/`: reusable view components
- `Sources/CaddyApp/ViewModels/`: UI state and orchestration
- `Sources/CaddyApp/ViewModels/Features/`: feature-specific UI state
- `Sources/CaddyApp/Services/`: Caddy, runtime, config, and system integration logic
- `Sources/CaddyApp/Models/`: domain models and feature catalog
- `docs/features/`: feature-level planning/progress documents
- `docs/repository/`: YAML app repository feed (for GitHub Pages)
- `scripts/`: build helpers and workflow automation scripts
- `assets/`: app icon and systray graphics

## Multipass Service Configuration

- Multipass VM discovery remains best effort via `multipass list --format json`.
- Optional VM-side auto-configuration file: `/etc/caddy-app.yaml`.
- Imported and manual Multipass services are stored in app custom config (`multipassServices`) with:
  - host + wildcard routing (`*.<service>.<vm>.mp.localhost`)
  - target port + scheme (`http` / `https`)
  - VM auto-start/auto-stop behavior
  - systemd unit configuration and control (`start` / `restart` / `stop`)

## Route Alias Toggle

- `.localhost` routes can optionally emit additional `*.traefik.me` aliases (`<host>.<ip>.traefik.me`) for active macOS IPv4 interfaces.
- The behavior is controlled by persisted custom config (`enableTraefikMeAliases`) and can be toggled in the Custom settings UI.

## Build and Run

- `make build`: debug build + app bundle generation
- `make release`: release build + app bundle generation
- `make run`: run app from SwiftPM
- `make check`: build + tests

## Automation Rules (Implemented)

### 1) Agent-commit after successful build

`make build` and `make release` do not create commits automatically.
After a successful build, the coding agent creates the commit.

Behavior:
- only commit when working tree is not clean
- stage all current changes (`git add -A`)
- use one short and precise commit message

### 2) Automatic feature documentation

Before the agent commit, this script can be called:
- `scripts/ensure_feature_doc.sh`

Behavior:
- creates a new `docs/features/NNN-<slug>.md` when:
  - current branch name matches `feat/...` or `feature/...`, or
  - `CADDYAPP_FEATURE=1` is set
- only creates a document when no other feature doc change is already present
- uses the existing feature template structure

Manual force example:

```bash
CADDYAPP_FEATURE=1 make build
```

### 3) YAML Repository Feed (GitHub Pages)

Repository feed files are versioned in:
- `docs/repository/repositories.yaml`
- `docs/repository/apps/index.yaml`
- `docs/repository/apps/*.yaml`

GitHub Actions workflow:
- `.github/workflows/pages.yml`

Behavior:
- deploys `docs/` to GitHub Pages on push to `main` when repository feed files change
- allows manual deployment via `workflow_dispatch`
- app-side repository URLs can be managed in the On-Demand preset picker and refreshed from web

## Recommended Branch Naming

For automatic feature-doc creation, use feature branches:

- `feat/reverse-proxy-rules`
- `feature/on-demand-routing`

## Documentation Workflow

- Keep `docs/features/` updated per feature status.
- Keep `README.md` concise for onboarding.
- Keep this file (`docs/PROJECT.md`) as the technical process overview.
