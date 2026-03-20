import SwiftUI

struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CaddyApp")
                .font(.headline)

            if let snapshot = viewModel.snapshot {
                Text(snapshot.caddyRuntimeStatus.isRunning ? "Caddy läuft" : "Caddy gestoppt")
                    .font(.caption)
                Text(snapshot.caddyInstall.isInstalled ? "Installation bereit" : "Caddy fehlt")
                    .font(.caption)
                    .foregroundStyle(snapshot.caddyRuntimeStatus.isRunning ? .green : .secondary)
                Text(viewModel.repositorySyncStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let warning = snapshot.warnings.first {
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else if let latest = snapshot.latestRelease {
                    Text("Release \(latest.tagName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(viewModel.isLoading ? "Lade Status..." : "Noch keine Daten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Dashboard öffnen") {
                openWindow(id: AppWindowController.mainWindowID)
            }
            Button("AppConfig öffnen") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Aktualisieren") {
                viewModel.refresh()
            }
            Button("Feed Sync") {
                viewModel.refreshAppRepositoryPresets()
            }
            .disabled(viewModel.isRefreshingAppRepositories)
            if let snapshot = viewModel.snapshot, snapshot.caddyInstall.isInstalled {
                Button(snapshot.caddyRuntimeStatus.isRunning ? "Caddy stoppen" : "Caddy starten") {
                    viewModel.setCaddyRunning(!snapshot.caddyRuntimeStatus.isRunning)
                }
            }
            Divider()
            Button("Beenden") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
        .frame(minWidth: 240)
    }
}
