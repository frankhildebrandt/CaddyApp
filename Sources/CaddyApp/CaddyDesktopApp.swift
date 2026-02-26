import SwiftUI

@main
struct CaddyDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var viewModel = DashboardViewModel.bootstrap()

    var body: some Scene {
        WindowGroup("CaddyApp", id: AppWindowController.mainWindowID) {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusView(viewModel: viewModel)
        } label: {
            MenuBarSystrayIcon()
        }
    }
}

private struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CaddyApp")
                .font(.headline)

            if let snapshot = viewModel.snapshot {
                Text(snapshot.caddyInstall.isInstalled ? "Caddy: installiert" : "Caddy: nicht installiert")
                    .font(.caption)
                Text(snapshot.caddyRuntimeStatus.isRunning ? "Status: läuft" : "Status: gestoppt")
                    .font(.caption)
                    .foregroundStyle(snapshot.caddyRuntimeStatus.isRunning ? .green : .secondary)
                Text("Routen: \(snapshot.configPreview.routeCount)")
                    .font(.caption)
                if let latest = snapshot.latestRelease {
                    Text("Latest: \(latest.tagName)")
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
            Button("Aktualisieren") {
                viewModel.refresh()
            }
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
