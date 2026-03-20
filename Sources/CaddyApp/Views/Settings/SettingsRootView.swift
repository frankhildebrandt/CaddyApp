import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var onDemandViewModel = OnDemandViewModel()
    @StateObject private var multipassViewModel = MultipassViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $settingsViewModel.selectedPane) {
                ForEach(SettingsPane.allCases) { pane in
                    NavigationLink(value: pane) {
                        Label(pane.title, systemImage: pane.systemImage)
                            .padding(.leading, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8))
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 250)
        } detail: {
            settingsDetail(for: settingsViewModel.selectedPane ?? .appBehavior)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 980, minHeight: 700)
        .onChange(of: dashboardViewModel.customRoutes) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.onDemandApps) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.multipassServices) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.appRepositories) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.enableTraefikMeAliases) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.hideWindowToMenuBarOnClose) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.repositoryAutoUpdateEnabled) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
        .onChange(of: dashboardViewModel.repositoryAutoUpdateIntervalHours) { _, _ in
            dashboardViewModel.scheduleDraftAutoSave()
        }
    }

    @ViewBuilder
    private func settingsDetail(for pane: SettingsPane) -> some View {
        switch pane {
        case .appBehavior:
            SettingsGeneralPaneView(dashboardViewModel: dashboardViewModel)
        case .repositorySync:
            SettingsFeedSyncPaneView(dashboardViewModel: dashboardViewModel)
        case .routing:
            SettingsCustomConfigPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel
            )
        case .apps:
            SettingsOnDemandPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel,
                onDemandViewModel: onDemandViewModel,
                presentationCoordinator: presentationCoordinator
            )
        case .services:
            SettingsServicesPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel,
                multipassViewModel: multipassViewModel
            )
        }
    }
}
