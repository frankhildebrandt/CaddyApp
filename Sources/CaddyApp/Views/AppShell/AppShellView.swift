import SwiftUI

struct AppShellView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator

    @State private var selectedTab: AppSidebarTab? = .overview

    var body: some View {
        GeometryReader { proxy in
            let shellTopPadding = max(8, min(proxy.safeAreaInsets.top * 0.18, 14))

            ZStack {
                AppAmbientBackground()
                    .ignoresSafeArea()

                NavigationSplitView {
                    AppSidebarView(
                        selectedTab: $selectedTab,
                        onOpenSupport: { AppWindowRouter.shared.openDocumentationWindow() },
                        onOpenSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                    )
                    .padding(.leading, 18)
                    .padding(.top, shellTopPadding)
                    .padding(.bottom, 18)
                    .navigationSplitViewColumnWidth(min: 230, ideal: 280)
                } detail: {
                    VStack(spacing: 0) {
                        AppHeaderView(
                            isLoading: viewModel.isLoading,
                            runtimeStatusText: runtimeStatusText,
                            syncStatusText: viewModel.repositorySyncStatusText,
                            onOpenSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) },
                            onRefresh: viewModel.refresh
                        )

                        detailContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(AppChrome.panelFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .stroke(AppChrome.border, lineWidth: 1)
                            )
                            .shadow(color: AppChrome.shadow, radius: 22, x: 0, y: 14)
                    )
                    .padding(.top, shellTopPadding)
                    .padding(.trailing, 18)
                    .padding(.bottom, 18)
                }
            }
            .navigationSplitViewStyle(.balanced)
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
            .onChange(of: viewModel.hideWindowToMenuBarOnClose) { _, _ in
                viewModel.scheduleDraftAutoSave()
            }
            .onChange(of: viewModel.repositoryAutoUpdateEnabled) { _, _ in
                viewModel.scheduleDraftAutoSave()
            }
            .onChange(of: viewModel.repositoryAutoUpdateIntervalHours) { _, _ in
                viewModel.scheduleDraftAutoSave()
            }
            .background(MainWindowDelegateInstaller())
            .overlay(alignment: .topLeading) {
                DocumentationSceneBridge()
            }
            .confirmationDialog(
                dialogTitle,
                isPresented: Binding(
                    get: { presentationCoordinator.activeDialog != nil },
                    set: { isPresented in
                        if !isPresented {
                            presentationCoordinator.dismissDialog()
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: presentationCoordinator.activeDialog
            ) { dialog in
                switch dialog {
                case .caddyUpdate:
                    Button("Update via Homebrew") {
                        viewModel.updateCaddy()
                    }
                case .reloadConfig:
                    Button("Schreiben und Reload ausführen") {
                        viewModel.reloadCaddy()
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    presentationCoordinator.dismissDialog()
                }
            } message: { dialog in
                Text(dialogMessage(dialog))
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let snapshot = viewModel.snapshot {
            switch selectedTab ?? .overview {
            case .overview:
                ScrollView {
                    DashboardTabView(snapshot: snapshot, openURLAction: openURL)
                }
            case .setupStatus:
                ScrollView {
                    SystemTabView(
                        snapshot: snapshot,
                        viewModel: viewModel,
                        showCaddyUpdateConfirmation: Binding(
                            get: { presentationCoordinator.activeDialog == .caddyUpdate },
                            set: { isPresented in
                                isPresented
                                    ? presentationCoordinator.present(.caddyUpdate)
                                    : presentationCoordinator.dismissDialog()
                            }
                        )
                    )
                }
            case .routing:
                ScrollView {
                    ConfigTabView(
                        snapshot: snapshot,
                        viewModel: viewModel,
                        showReloadConfigConfirmation: Binding(
                            get: { presentationCoordinator.activeDialog == .reloadConfig },
                            set: { isPresented in
                                isPresented
                                    ? presentationCoordinator.present(.reloadConfig)
                                    : presentationCoordinator.dismissDialog()
                            }
                        )
                    )
                }
            case .services:
                ServicesWorkspaceView(snapshot: snapshot, viewModel: viewModel)
            case .apps:
                AppsWorkspaceView(
                    snapshot: snapshot,
                    viewModel: viewModel,
                    presentationCoordinator: presentationCoordinator
                )
            case .monitoring:
                ScrollView {
                    MonitoringWorkspaceView(snapshot: snapshot, viewModel: viewModel)
                }
            }
        } else if viewModel.isLoading {
            AppSkeletonView()
        } else if (selectedTab ?? .overview) == .monitoring {
            ScrollView {
                MonitoringWorkspaceView(snapshot: nil, viewModel: viewModel)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Noch keine Daten geladen")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                Text("Lade den ersten Snapshot, um Runtime, Routing und Monitoring im neuen Workspace sichtbar zu machen.")
                    .foregroundStyle(AppChrome.secondaryText)
            }
            .padding(28)
            .appGlassCard(cornerRadius: 28, fill: AppChrome.panelFill)
        }
    }
}

private extension AppShellView {
    var runtimeStatusText: String {
        guard let snapshot = viewModel.snapshot else {
            return viewModel.isLoading ? "Lädt" : "Bereit"
        }
        return snapshot.caddyRuntimeStatus.isRunning ? "Aktiv" : "Gestoppt"
    }

    var dialogTitle: String {
        switch presentationCoordinator.activeDialog {
        case .caddyUpdate:
            return "Caddy aktualisieren?"
        case .reloadConfig:
            return "Caddy-Konfiguration anwenden?"
        case .none:
            return ""
        }
    }

    private func dialogMessage(_ dialog: AppPresentationCoordinator.Dialog) -> String {
        switch dialog {
        case .caddyUpdate:
            return "Homebrew wird bevorzugt. Falls nötig, fällt die App auf das verwaltete Binary oder eine Recovery per 'brew reinstall caddy' zurück."
        case .reloadConfig:
            return "Die Vorschau wird geschrieben, validiert und bei Fehlern automatisch auf die letzte funktionierende Datei zurückgesetzt."
        }
    }
}
