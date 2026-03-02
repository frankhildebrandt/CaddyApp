import SwiftUI

@main
struct CaddyDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var viewModel = DashboardViewModel.bootstrap()
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false

    init() {
        Task {
            await OnDemandAppsService.shared.startIfNeeded()
            await OnDemandAppsService.shared.reloadConfiguration()
        }
    }

    var body: some Scene {
        WindowGroup("CaddyApp", id: AppWindowController.mainWindowID) {
            AppShellView(viewModel: viewModel)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusView(viewModel: viewModel)
        } label: {
            MenuBarSystrayIcon()
        }

        Settings {
            AppSettingsView(
                viewModel: viewModel,
                hideWindowToMenuBarOnClose: $hideWindowToMenuBarOnClose
            )
        }

        .commands {
            CommandMenu("CaddyApp") {
                Button("Dashboard öffnen") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.unhide(nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Aktualisieren") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                if let snapshot = viewModel.snapshot, snapshot.caddyInstall.isInstalled {
                    Button(snapshot.caddyRuntimeStatus.isRunning ? "Caddy stoppen" : "Caddy starten") {
                        viewModel.setCaddyRunning(!snapshot.caddyRuntimeStatus.isRunning)
                    }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                }

                Divider()

                SettingsLink {
                    Label("Einstellungen...", systemImage: "gearshape")
                }
            }
        }
    }
}
