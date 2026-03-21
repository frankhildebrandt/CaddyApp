import SwiftUI

@main
struct CaddyDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var viewModel = DashboardViewModel.bootstrap()
    @StateObject private var presentationCoordinator = AppPresentationCoordinator()

    init() {
        Task {
            await OnDemandAppsService.shared.startIfNeeded()
            await OnDemandAppsService.shared.reloadConfiguration()
        }
    }

    var body: some Scene {
        WindowGroup("CaddyApp", id: AppWindowController.mainWindowID) {
            AppShellView(
                viewModel: viewModel,
                presentationCoordinator: presentationCoordinator
            )
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Window("Dokumentation", id: AppWindowController.documentationWindowID) {
            DocumentationWindowView()
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusView(
                viewModel: viewModel,
                presentationCoordinator: presentationCoordinator
            )
        } label: {
            MenuBarSystrayIcon()
        }

        Settings {
            AppSettingsView(viewModel: viewModel, presentationCoordinator: presentationCoordinator)
        }

        .commands {
            CommandMenu("CaddyApp") {
                Button("Dashboard öffnen") {
                    AppWindowRouter.shared.openMainWindow()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Dokumentation öffnen (F1)") {
                    AppWindowRouter.shared.openDocumentationWindow()
                }

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
