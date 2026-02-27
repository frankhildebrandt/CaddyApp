import Foundation

enum FeatureCatalog {
    static let items: [FeatureItem] = [
        FeatureItem(
            id: "F-010",
            title: "Caddy Installation & Updates",
            status: .done,
            summary: "Detect local installation, show version/update state, and run Homebrew update workflows.",
            documentPath: "docs/features/010-caddy-installation-updates.md"
        ),
        FeatureItem(
            id: "F-020",
            title: "Reverse Proxy for localhost Subdomains",
            status: .done,
            summary: "Manage reverse proxy routes and generate Caddyfile snippets for localhost domains.",
            documentPath: "docs/features/020-reverse-proxy-localhost.md"
        ),
        FeatureItem(
            id: "F-030",
            title: "AutoTLS & Root Certificate",
            status: .done,
            summary: "Enable tls internal, explain CA trust installation, and simplify root certificate onboarding.",
            documentPath: "docs/features/030-autotls-root-cert.md"
        ),
        FeatureItem(
            id: "F-040",
            title: "Multipass & Podman Runtime Discovery",
            status: .done,
            summary: "Discover local Multipass/Podman runtimes and derive bootstrap targets for proxy routing.",
            documentPath: "docs/features/040-runtime-discovery-multipass-podman.md"
        ),
        FeatureItem(
            id: "F-050",
            title: "Caddy Release Monitoring",
            status: .done,
            summary: "Poll upstream releases and compare with the local version before suggesting updates.",
            documentPath: "docs/features/050-release-monitoring.md"
        ),
        FeatureItem(
            id: "F-060",
            title: "Feature Progress Tracking",
            status: .done,
            summary: "Track implementation state in per-feature documents and a central progress index.",
            documentPath: "docs/features/000-overview.md"
        ),
        FeatureItem(
            id: "F-070",
            title: "Menu Bar / Systray Integration",
            status: .done,
            summary: "Keep the app available in the macOS menu bar and reopen the dashboard from the tray.",
            documentPath: "docs/features/070-menubar-systray.md"
        ),
        FeatureItem(
            id: "F-080",
            title: "On-Demand Container Apps",
            status: .done,
            summary: "Define Docker/Podman apps that auto-start on URL access and stop after inactivity.",
            documentPath: "docs/features/080-on-demand-container-apps.md"
        ),
        FeatureItem(
            id: "F-090",
            title: "YAML App Repositories",
            status: .done,
            summary: "Define and distribute custom app presets via web-updatable YAML repositories.",
            documentPath: "docs/features/090-yaml-app-repositories.md"
        )
    ]
}
