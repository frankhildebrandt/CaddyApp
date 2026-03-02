import SwiftUI

extension ContentView {
    enum ConfigDialogPane: String, CaseIterable, Identifiable {
        case general
        case onDemandApps = "on_demand_apps"
        case services
        case customConfig = "custom_config"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "Allgemein"
            case .onDemandApps: return "On-Demand Apps"
            case .services: return "Services"
            case .customConfig: return "Custom Config"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .onDemandApps: return "bolt.badge.clock"
            case .services: return "shippingbox"
            case .customConfig: return "slider.horizontal.3"
            }
        }
    }

    private var configurationDialog: some View {
        NavigationSplitView {
            List(selection: $selectedConfigDialogPane) {
                ForEach(ConfigDialogPane.allCases) { pane in
                    Label(pane.title, systemImage: pane.systemImage)
                        .tag(pane)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 230)
        } detail: {
            List {
                settingsDetailContent
            }
            .listStyle(.automatic)
            .id(selectedConfigDialogPane)
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    var settingsConfigurationContent: some View {
        configurationDialog
            .sheet(isPresented: $showOnDemandPresetPicker) {
                onDemandPresetPickerSheet
                    .onAppear {
                        if !viewModel.isRefreshingAppRepositories, viewModel.remoteOnDemandPresets.isEmpty {
                            viewModel.refreshAppRepositoryPresets()
                        }
                    }
            }
    }

    private var settingsGeneralPane: some View {
        Section("Allgemein") {
            Toggle("Schließen in Menüleiste minimieren", isOn: $hideWindowToMenuBarOnClose)
        }
    }

    @ViewBuilder
    private var settingsDetailContent: some View {
        switch selectedConfigDialogPane {
        case .general:
            settingsGeneralPane
        case .onDemandApps:
            if let snapshot = viewModel.snapshot {
                onDemandAppsSection(snapshot)
            } else {
                appSkeletonState
            }
        case .services:
            if let snapshot = viewModel.snapshot {
                multipassSection(snapshot)
            } else {
                appSkeletonState
            }
        case .customConfig:
            if let snapshot = viewModel.snapshot {
                customConfigSection(snapshot)
            } else {
                appSkeletonState
            }
        }
    }
}
