# F-090 Automatic Release Build

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-27

## Goal

Automatically build the macOS app bundle and attach it as a downloadable asset whenever a GitHub Release is created.

## Scope

- In scope: GitHub Actions workflow triggered on release creation.
- In scope: Release binary built with `swift build -c release`.
- In scope: App bundle assembled via existing `make_macos_app_bundle.sh` script.
- In scope: App bundle packaged as `CaddyApp.zip` and uploaded to the GitHub Release.
- In scope: App version derived from the release tag.
- Out of scope: Code signing and notarisation (developer certificate required).
- Out of scope: Homebrew tap / auto-update integration.

## Acceptance Criteria

- [x] Workflow file exists at `.github/workflows/release.yml`.
- [x] Workflow is triggered on `release: types: [created]`.
- [x] Workflow builds with `swift build -c release`.
- [x] App bundle is created via `make_macos_app_bundle.sh`.
- [x] `CaddyApp.zip` is attached to the release as a downloadable asset.
- [x] App version in `Info.plist` matches the release tag.

## Implementation Notes

- The workflow uses `macos-latest` so that all required Apple tooling (`swift`, `sips`, `iconutil`) is available.
- Icon generation (`generate_app_icon.sh`) uses `qlmanage` which may not render SVGs in a headless environment; the step is allowed to fail gracefully (`|| echo "Icon generation skipped"`).
- Auto-commit script is not invoked in CI (no git identity configured in the runner).
- The `GITHUB_TOKEN` permission `contents: write` is required to upload release assets.

## Progress Log

- 2026-02-27: Created workflow and feature document.
