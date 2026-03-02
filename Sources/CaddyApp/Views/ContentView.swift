import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) var openURL
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

    enum OnDemandSubTab: String, CaseIterable, Identifiable {
        case config
        case hostLog = "host_log"
        case containerLog = "container_log"
        case shell
        case eventLog = "event_log"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .config: return "Config"
            case .hostLog: return "Host-Log"
            case .containerLog: return "Container/Pod-Log"
            case .shell: return "Shell"
            case .eventLog: return "Eventlog"
            }
        }
    }

    private enum SidebarTab: String, CaseIterable, Identifiable {
        case dashboard
        case caddyTLS = "caddy_tls"
        case runtime
        case config
        case logs
        case features

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .caddyTLS: return "Caddy & TLS"
            case .runtime: return "Runtime"
            case .config: return "Config"
            case .logs: return "Logging"
            case .features: return "Features"
            }
        }

        var systemImage: String {
            switch self {
            case .dashboard: return "rectangle.grid.2x2"
            case .caddyTLS: return "lock.shield"
            case .runtime: return "server.rack"
            case .config: return "doc.text"
            case .logs: return "terminal"
            case .features: return "list.bullet.clipboard"
            }
        }
    }

    @ObservedObject var viewModel: DashboardViewModel
    @StateObject var onDemandShellSession = OnDemandEmbeddedShellSession()
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false
    @State var showCaddyUpdateConfirmation = false
    @State var showReloadConfigConfirmation = false
    @State private var selectedTab: SidebarTab? = .dashboard
    @State var selectedOnDemandAppID: UUID?
    @State var selectedOnDemandSubTab: OnDemandSubTab = .config
    @State var showOnDemandPresetPicker = false
    @State var onDemandShellInput = ""
    @State var onDemandHostLogByAppID: [UUID: String] = [:]
    @State var onDemandContainerLogByAppID: [UUID: String] = [:]
    @State var onDemandEventLogByAppID: [UUID: String] = [:]
    @State var onDemandLoadingByAppID: [UUID: Bool] = [:]
    @State var showConfigurationDialog = false
    @State var selectedConfigDialogPane: ConfigDialogPane = .general

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            NavigationSplitView {
                sidebar
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
        .onChange(of: selectedTab) { _, _ in
            onDemandShellSession.stop()
        }
        .background(MainWindowDelegateInstaller())
        .sheet(isPresented: $showOnDemandPresetPicker) {
            onDemandPresetPickerSheet
                .onAppear {
                    if !viewModel.isRefreshingAppRepositories, viewModel.remoteOnDemandPresets.isEmpty {
                        viewModel.refreshAppRepositoryPresets()
                    }
                }
        }
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

    private var sidebar: some View {
        List(selection: $selectedTab) {
            ForEach(SidebarTab.allCases) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
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
                    appSkeletonState
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

    private var header: some View {
        HStack {
            HStack(alignment: .top, spacing: 12) {
                AppBrandIcon(size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("CaddyApp")
                        .font(.title.bold())
                    Text("Lokales Caddy Control Center")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                AppWindowController().hideAppToMenuBar()
            } label: {
                Label("Menüleiste", systemImage: "menubar.dock.rectangle")
            }
            .buttonStyle(.bordered)
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            Toggle("Schließen versteckt", isOn: $hideWindowToMenuBarOnClose)
                .toggleStyle(.checkbox)
            Button {
                viewModel.refresh()
            } label: {
                Label(viewModel.isLoading ? "Lädt..." : "Aktualisieren", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(20)
            }
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
        GroupBox("Allgemein") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Schließen in Menüleiste minimieren", isOn: $hideWindowToMenuBarOnClose)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


    private var appSkeletonState: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 112)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 160, height: 10)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                                .frame(maxWidth: .infinity)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                                .frame(width: 220, height: 10)
                        }
                        .padding(14),
                        alignment: .topLeading
                    )
                    .redacted(reason: .placeholder)
            }
        }
    }

    var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }

    func onDemandPhaseColor(_ phase: OnDemandAppPhase) -> Color {
        switch phase {
        case .running:
            return .green
        case .starting, .stopping:
            return .orange
        case .error:
            return .red
        case .stopped:
            return .secondary
        }
    }

    func multipassAutoHost(for name: String) -> String? {
        let lowered = name.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber || character == "-" {
                return character
            }
            return "-"
        }
        let label = String(mapped)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        guard !label.isEmpty else { return nil }
        let truncated = String(label.prefix(63))
        return "\(truncated).mp.localhost"
    }
}

struct InlineActivitySkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 64, height: 14)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Lädt")
    }
}

private struct MainWindowDelegateInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = MainWindowCloseDelegate.shared
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.delegate = MainWindowCloseDelegate.shared
        }
    }
}
