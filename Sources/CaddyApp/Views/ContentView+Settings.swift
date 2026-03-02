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
                    NavigationLink(value: pane) {
                        Label(pane.title, systemImage: pane.systemImage)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 230)
        } detail: {
            settingsDetailList(for: selectedConfigDialogPane ?? .general)
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
    private func settingsDetailList(for pane: ConfigDialogPane) -> some View {
        switch pane {
        case .general:
            List {
                settingsGeneralPane
            }
            .listStyle(.automatic)
        case .onDemandApps:
            List {
                if let snapshot = viewModel.snapshot {
                    onDemandAppsSection(snapshot)
                } else {
                    appSkeletonState
                }
            }
            .listStyle(.automatic)
        case .services:
            List {
                if let snapshot = viewModel.snapshot {
                    multipassSection(snapshot)
                } else {
                    appSkeletonState
                }
            }
            .listStyle(.automatic)
        case .customConfig:
            List {
                if let snapshot = viewModel.snapshot {
                    customConfigSection(snapshot)
                } else {
                    appSkeletonState
                }
            }
            .listStyle(.automatic)
        }
    }
}
