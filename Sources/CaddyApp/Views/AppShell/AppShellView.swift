import SwiftUI

struct AppShellView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator

    @State private var selectedTab: AppSidebarTab? = .overview

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppChrome.canvasTop, AppChrome.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 18) {
                AppSidebarView(
                    selectedTab: $selectedTab,
                    onOpenSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                )
                .frame(width: 300)

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
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(AppChrome.contentCanvas)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(18)
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
        if let snapshot = viewModel.snapshot {
            switch selectedTab ?? .overview {
            case .overview:
                ScrollView {
                    DashboardTabView(snapshot: snapshot, openURLAction: openURL)
                        .frame(maxWidth: 1100, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .frame(maxWidth: 1100, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .frame(maxWidth: 1100, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .services:
                ServicesWorkspaceView(snapshot: snapshot, viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .apps:
                AppsWorkspaceView(
                    snapshot: snapshot,
                    viewModel: viewModel,
                    presentationCoordinator: presentationCoordinator
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .monitoring:
                MonitoringWorkspaceView(snapshot: snapshot, viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else if viewModel.isLoading {
            AppSkeletonView()
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if (selectedTab ?? .overview) == .monitoring {
            MonitoringWorkspaceView(snapshot: nil, viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("No data loaded yet")
                .foregroundStyle(.secondary)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
