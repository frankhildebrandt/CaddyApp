# F-100 Automatic Release Build

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-03-30

## Goal

Automatically build the macOS app bundle and attach it as a downloadable asset whenever a GitHub Release is created.

## Scope

- In scope: GitHub Actions workflow triggered on release creation.
- In scope: Release binary built as Universal Binary (`arm64` + `x86_64`).
- In scope: App bundle assembled via existing `make_macos_app_bundle.sh` script.
- In scope: App bundle packaged as `CaddyApp.zip` and uploaded to the GitHub Release.
- In scope: Local production target creates the same universal app bundle under `_build/production/`.
- In scope: Local DMG packaging with Finder background image and `Applications` alias.
- In scope: App version derived from the release tag.
- Out of scope: Code signing and notarisation (developer certificate required).
- Out of scope: Homebrew tap / auto-update integration.

## Acceptance Criteria

- [x] Workflow file exists at `.github/workflows/release.yml`.
- [x] Workflow is triggered on `release: types: [created]`.
- [x] Workflow builds with `swift build -c release --arch arm64 --arch x86_64`.
- [x] App bundle is created via `make_macos_app_bundle.sh`.
- [x] `CaddyApp.zip` is attached to the release as a downloadable asset.
- [x] App version in `Info.plist` matches the release tag.
- [x] `make production` creates `_build/production/CaddyApp.app` and `_build/production/CaddyApp.zip`.
- [x] `make dmg` creates `_build/production/CaddyApp.dmg` with background image and `Applications` link.

## Implementation Notes

- The workflow uses `macos-latest` so that all required Apple tooling (`swift`, `sips`, `iconutil`) is available.
- Icon generation (`generate_app_icon.sh`) uses `qlmanage` which may not render SVGs in a headless environment; the step is allowed to fail gracefully (`|| echo "Icon generation skipped"`).
- The app bundle script copies SwiftPM `*.bundle` resources into `CaddyApp.app/Contents/Resources` so `Bundle.module` lookups work in distributed builds.
- Local `make production` uses the SwiftPM universal output path `_build/swiftpm/apple/Products/Release/CaddyApp`.
- DMG creation uses a temporary read-write image, copies a background image into `.background/`, adds an `Applications` symlink, and applies Finder layout via AppleScript before converting to a compressed final image.
- Repository commits are handled by the coding agent after successful local builds; CI build flow stays commit-free.
- The `GITHUB_TOKEN` permission `contents: write` is required to upload release assets.
- First-start Gatekeeper behavior on downloaded ZIPs is documented in `README.md` (quarantine removal fallback).

## Progress Log

- 2026-02-27: Created workflow and feature document.
- 2026-03-02: Switched release build to universal (`arm64` + `x86_64`) and added architecture verification step in CI.
- 2026-03-02: Fixed startup crash in packaged apps by bundling SwiftPM resource bundles (`*.bundle`) into the generated `.app`.
- 2026-03-30: Added local `make production` and `make dmg` targets for universal distribution artifacts and DMG packaging with Finder layout.
