import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @Binding var hideWindowToMenuBarOnClose: Bool
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var onDemandViewModel = OnDemandViewModel()
    @StateObject private var multipassViewModel = MultipassViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $settingsViewModel.selectedPane) {
                ForEach(SettingsPane.allCases) { pane in
                    NavigationLink(value: pane) {
                        Label(pane.title, systemImage: pane.systemImage)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 230)
        } detail: {
            settingsDetail(for: settingsViewModel.selectedPane ?? .general)
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    @ViewBuilder
    private func settingsDetail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            SettingsGeneralPaneView(hideWindowToMenuBarOnClose: $hideWindowToMenuBarOnClose)
        case .onDemandApps:
            SettingsOnDemandPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel,
                settingsViewModel: settingsViewModel,
                onDemandViewModel: onDemandViewModel
            )
        case .services:
            SettingsServicesPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel,
                multipassViewModel: multipassViewModel
            )
        case .customConfig:
            SettingsCustomConfigPaneView(
                snapshot: dashboardViewModel.snapshot,
                dashboardViewModel: dashboardViewModel
            )
        }
    }
}
