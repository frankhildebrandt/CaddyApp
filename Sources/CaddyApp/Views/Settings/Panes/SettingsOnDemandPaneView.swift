import SwiftUI

struct SettingsOnDemandPaneView: View {
    let snapshot: DashboardSnapshot?
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var onDemandViewModel: OnDemandViewModel

    var body: some View {
        List {
            if let snapshot {
                Section {
                    onDemandAppsSection(snapshot)
                }
            } else {
                AppSkeletonView()
            }
        }
        .listStyle(.automatic)
        .sheet(isPresented: $settingsViewModel.showOnDemandPresetPicker) {
            OnDemandPresetPickerView(
                dashboardViewModel: dashboardViewModel,
                onDemandViewModel: onDemandViewModel,
                isPresented: $settingsViewModel.showOnDemandPresetPicker
            )
        }
    }

    private func onDemandAppsSection(_ snapshot: DashboardSnapshot) -> some View {
        let statusesByID = Dictionary(uniqueKeysWithValues: snapshot.onDemandAppStatuses.map { ($0.appID, $0) })

        return VStack(alignment: .leading, spacing: 16) {
            GroupBox("On-Demand Apps") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Apps starten automatisch beim URL-Zugriff und stoppen nach Idle-Timeout.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if onDemandViewModel.selectedOnDemandAppID != nil {
                            Button {
                                onDemandViewModel.onDemandShellSession.stop()
                                onDemandViewModel.selectedOnDemandAppID = nil
                            } label: {
                                Label("Zurück zur Liste", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            dashboardViewModel.refreshAppRepositoryPresets()
                        } label: {
                            Label("Web-Update", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(dashboardViewModel.isRefreshingAppRepositories)

                        Button {
                            settingsViewModel.showOnDemandPresetPicker = true
                        } label: {
                            Label("Hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if dashboardViewModel.onDemandApps.isEmpty {
                        Text("Noch keine On-Demand-App angelegt.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else if let selectedID = onDemandViewModel.selectedOnDemandAppID,
                              let appBinding = onDemandViewModel.bindingForOnDemandApp(viewModel: dashboardViewModel, id: selectedID) {
                        let runtimeStatus = statusesByID[selectedID]
                        OnDemandDetailView(
                            dashboardViewModel: dashboardViewModel,
                            onDemandViewModel: onDemandViewModel,
                            app: appBinding,
                            runtimeStatus: runtimeStatus
                        )
                        .onAppear {
                            onDemandViewModel.loadOnDemandSubTab(
                                tab: onDemandViewModel.selectedOnDemandSubTab,
                                app: appBinding.wrappedValue,
                                viewModel: dashboardViewModel
                            )
                        }
                    } else {
                        OnDemandListView(
                            apps: dashboardViewModel.onDemandApps,
                            statusesByID: statusesByID,
                            phaseColor: onDemandViewModel.onDemandPhaseColor
                        ) { app in
                            onDemandViewModel.selectedOnDemandAppID = app.id
                            onDemandViewModel.selectedOnDemandSubTab = .config
                            onDemandViewModel.loadOnDemandSubTab(tab: .config, app: app, viewModel: dashboardViewModel)
                        }
                    }

                    Text("Änderungen werden automatisch gespeichert und bei gültiger Konfiguration direkt auf Caddy angewendet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let validationError = dashboardViewModel.customConfigValidationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                    }
                    if let saveResult = dashboardViewModel.lastCustomConfigSaveResult {
                        StatusMessageView(message: saveResult.message, isSuccess: saveResult.succeeded)
                    }
                    if let controlResult = dashboardViewModel.lastOnDemandAppControlResult {
                        StatusMessageView(message: controlResult.message, isSuccess: controlResult.succeeded)
                    }
                    if let repositoryResult = dashboardViewModel.lastRepositorySyncResult {
                        StatusMessageView(message: repositoryResult.message, isSuccess: repositoryResult.succeeded)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
