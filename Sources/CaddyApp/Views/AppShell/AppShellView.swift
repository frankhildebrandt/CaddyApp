import SwiftUI

struct AppShellView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator

    @State private var selectedTab: AppSidebarTab? = .overview

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(
                isLoading: viewModel.isLoading,
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

    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = viewModel.snapshot {
                    switch selectedTab ?? .overview {
                    case .overview:
                        DashboardTabView(snapshot: snapshot, openURLAction: openURL)
                    case .setupStatus:
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
                    case .routing:
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
                    case .services:
                        ServicesWorkspaceView(snapshot: snapshot, viewModel: viewModel)
                    case .apps:
                        AppsWorkspaceView(
                            snapshot: snapshot,
                            viewModel: viewModel,
                            presentationCoordinator: presentationCoordinator
                        )
                    case .monitoring:
                        MonitoringWorkspaceView(snapshot: snapshot, viewModel: viewModel)
                    }
                } else if viewModel.isLoading {
                    AppSkeletonView()
                        .padding(.top, 6)
                } else if (selectedTab ?? .overview) == .monitoring {
                    MonitoringWorkspaceView(snapshot: nil, viewModel: viewModel)
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

    private var dialogTitle: String {
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
