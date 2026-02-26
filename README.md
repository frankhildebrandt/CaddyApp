# CaddyApp

Bootstrap for a macOS SwiftUI app to configure and manage the Caddy web server with focus on localhost reverse proxies.

## Included in this bootstrap

- SwiftUI macOS dashboard (`swift run`)
- macOS menu bar (Systray) integration with dashboard reopen action
- Local Caddy install/version detection
- Automatic Caddy bootstrap install attempt (Homebrew first, direct download fallback) when missing
- Caddy release metadata lookup (GitHub API)
- `*.localhost` reverse proxy Caddyfile preview with `tls internal`
- `Validate` / `Reload` automatically persist the current preview before executing Caddy commands
- `Reload Caddy` falls back to `caddy start` if no Caddy instance is currently running
- `Reload Caddy` retries via the macOS administrator dialog when elevated rights are required (no hidden CLI password prompt)
- Caddy starts automatically on app startup (when installed) using the generated config
- UI toggle shows the current Caddy runtime state and can start/stop Caddy
- Generated config changes are auto-validated and auto-reloaded when valid
- Caddy can be installed/updated without Homebrew (app-managed binary in `~/Library/Application Support/CaddyApp/bin/caddy`)
- Local Caddy CA root certificate path detection, auto-generation bootstrap, and trust guidance
- Root certificate trust action uses the macOS administrator dialog (no terminal password prompt required)
- Multipass / Podman discovery stubs (best effort)
- Automatic Multipass routes: `{vm-name}.mp.localhost` and `*.{vm-name}.mp.localhost` (AutoTLS via `tls internal`)
- Feature progress documents in `docs/features/`

## Run

```bash
swift run
```

## Makefile

```bash
make help
make build
make open-app
make check
```

`make build` erzeugt ein vollstaendiges macOS-App-Bundle unter `_build/debug/CaddyApp.app` (Release: `_build/release/CaddyApp.app`).

## Next engineering steps

1. Harden config apply flow with confirmations, backups, and rollback.
2. Add privilege-aware trust/install flow for local root certificate.
3. Add route approval UI for discovered Multipass/Podman workloads.
4. Add background release checks and user notifications.
