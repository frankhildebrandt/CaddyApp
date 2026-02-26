# F-030 AutoTLS & Root Certificate

## Status

- State: Done
- Owner: TBD
- Last Updated: 2026-02-26

## Goal

Make Caddy's local CA trust flow understandable and simple so `tls internal` works reliably for `*.localhost`.

## Scope

- In scope: Detect local Caddy root CA file.
- In scope: Provide trust/install guidance for macOS Keychain.
- In scope: Prefer `caddy trust` as the primary workflow.
- Out of scope: Fully automated privileged trust installation in bootstrap version.

## Acceptance Criteria

- [x] App reports whether the local root certificate file exists.
- [x] App shows root certificate path and trust command hint.
- [x] If no local Caddy CA root exists, app attempts automatic root generation bootstrap.
- [x] App can trigger trust installation and show result/errors.
- [x] App verifies certificate trust status in System Keychain.

## Implementation Notes

- Caddy root CA path is currently inferred from default Caddy PKI location.
- `sudo caddy trust` may require privileges and should be wrapped with explicit confirmation.
- Bootstrap trust action uses the macOS administrator dialog (`osascript` / AppleScript `do shell script ... with administrator privileges`) so no hidden CLI password prompt is required.
- A future version should validate trust via `security` CLI or Security framework APIs.

## Progress Log

- 2026-02-26: Added TLS status model and root certificate path presence check.
- 2026-02-26: Added automatic local CA generation bootstrap using a temporary `tls internal` Caddy site.
- 2026-02-26: Added `caddy trust` action using macOS authorization dialog with UI status output.
- 2026-02-26: Added System Keychain trust verification by matching the local root certificate SHA-256 fingerprint against `security find-certificate -Z` output.
