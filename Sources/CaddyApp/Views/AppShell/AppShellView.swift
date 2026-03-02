import SwiftUI

struct AppShellView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: DashboardViewModel
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false

    @State private var selectedTab: AppSidebarTab? = .dashboard
    @State private var showCaddyUpdateConfirmation = false
    @State private var showReloadConfigConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(
                hideWindowToMenuBarOnClose: $hideWindowToMenuBarOnClose,
                isLoading: viewModel.isLoading,
                onHideToMenuBar: { AppWindowController().hideAppToMenuBar() },
                onOpenSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) },
                onRefresh: viewModel.refresh
            )
            Divider()
            NavigationSplitView {
                AppSidebarView(selectedTab: $selectedTab)
            } detail: {
                detailContent
            }
        }
        .onAppear {
            viewModel.refreshIfNeeded()
        }
        .onChange(of: viewModel.customRoutes) { _, _ in
            viewModel.scheduleDraftAutoSave()
        }
        .onChange(of: viewModel.onDemandApps) { _, _ in
            viewModel.scheduleDraftAutoSave()
        }
        .onChange(of: viewModel.multipassServices) { _, _ in
            viewModel.scheduleDraftAutoSave()
        }
        .onChange(of: viewModel.appRepositories) { _, _ in
            viewModel.scheduleDraftAutoSave()
        }
        .onChange(of: viewModel.enableTraefikMeAliases) { _, _ in
            viewModel.scheduleDraftAutoSave()
        }
        .background(MainWindowDelegateInstaller())
        .confirmationDialog(
            "Caddy aktualisieren?",
            isPresented: $showCaddyUpdateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Update via Homebrew") {
                viewModel.updateCaddy()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die App nutzt Homebrew, wenn verfügbar. Ohne Homebrew (oder bei app-verwaltetem Caddy) wird ein direkter Download des aktuellen GitHub-Releases in den App-Bin-Pfad verwendet. Bei fehlgeschlagenem Homebrew-Upgrade wird eine Recovery via 'brew reinstall caddy' versucht.")
        }
        .confirmationDialog(
            "Caddy-Konfiguration anwenden?",
            isPresented: $showReloadConfigConfirmation,
            titleVisibility: .visible
        ) {
            Button("Schreiben und Reload ausführen") {
                viewModel.reloadCaddy()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die aktuelle Vorschau wird zuerst als Caddyfile geschrieben, vor dem Reload validiert und bei einem Fehler automatisch auf die vorherige Datei zurückgesetzt.")
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = viewModel.snapshot {
                    switch selectedTab ?? .dashboard {
                    case .dashboard:
                        DashboardTabView(snapshot: snapshot, openURLAction: openURL)
                    case .caddyTLS:
                        SystemTabView(
                            snapshot: snapshot,
                            viewModel: viewModel,
                            showCaddyUpdateConfirmation: $showCaddyUpdateConfirmation
                        )
                    case .runtime:
                        RuntimeTabView(snapshot: snapshot)
                    case .config:
                        ConfigTabView(
                            snapshot: snapshot,
                            viewModel: viewModel,
                            showReloadConfigConfirmation: $showReloadConfigConfirmation
                        )
                    case .logs:
                        LogsTabView(viewModel: viewModel)
                    case .features:
                        FeaturesTabView(snapshot: snapshot)
                    }
                } else if viewModel.isLoading {
                    AppSkeletonView()
                        .padding(.top, 6)
                } else if (selectedTab ?? .dashboard) == .logs {
                    LogsTabView(viewModel: viewModel)
                } else {
                    Text("No data loaded yet")
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
