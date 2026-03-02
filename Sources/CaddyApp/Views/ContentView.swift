import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    enum ConfigDialogPane: String, CaseIterable, Identifiable {
        case onDemandApps = "on_demand_apps"
        case services
        case customConfig = "custom_config"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .onDemandApps: return "On-Demand Apps"
            case .services: return "Services"
            case .customConfig: return "Custom Config"
            }
        }

        var systemImage: String {
            switch self {
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
        case multipass
        case onDemandApps = "on_demand_apps"
        case custom
        case config
        case logs
        case features

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .caddyTLS: return "Caddy & TLS"
            case .runtime: return "Runtime"
            case .multipass: return "Multipass"
            case .onDemandApps: return "On-Demand Apps"
            case .custom: return "Custom"
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
            case .multipass: return "shippingbox"
            case .onDemandApps: return "bolt.badge.clock"
            case .custom: return "slider.horizontal.3"
            case .config: return "doc.text"
            case .logs: return "terminal"
            case .features: return "list.bullet.clipboard"
            }
        }
    }

    @ObservedObject var viewModel: DashboardViewModel
    @StateObject var onDemandShellSession = OnDemandEmbeddedShellSession()
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false
    @State private var showCaddyUpdateConfirmation = false
    @State private var showReloadConfigConfirmation = false
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
    @State var selectedConfigDialogPane: ConfigDialogPane? = .onDemandApps

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
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .onDemandApps {
                selectedOnDemandAppID = nil
            } else {
                onDemandShellSession.stop()
            }
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
        .sheet(isPresented: $showConfigurationDialog) {
            configurationDialog
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
                        dashboardSection(snapshot)
                        warningSection(snapshot.warnings)
                        autoSetupSection(snapshot.autoSetupReport)
                    case .caddyTLS:
                        systemSection(snapshot)
                    case .runtime:
                        runtimeSection(snapshot)
                    case .multipass:
                        movedToConfigurationDialogView(
                            title: "Services wurden verschoben",
                            description: "Multipass- und Service-Konfigurationen sind jetzt im zentralen Konfigurationsdialog.",
                            pane: .services
                        )
                    case .onDemandApps:
                        movedToConfigurationDialogView(
                            title: "On-Demand Konfiguration wurde verschoben",
                            description: "On-Demand-Apps werden jetzt im zentralen Konfigurationsdialog verwaltet.",
                            pane: .onDemandApps
                        )
                    case .custom:
                        movedToConfigurationDialogView(
                            title: "Custom Config wurde verschoben",
                            description: "Custom Routes und zusätzliche Caddyfile-Konfiguration liegen jetzt im zentralen Konfigurationsdialog.",
                            pane: .customConfig
                        )
                    case .config:
                        configSection(snapshot)
                    case .logs:
                        loggingSection()
                    case .features:
                        featureSection(snapshot)
                    }
                } else if viewModel.isLoading {
                    appSkeletonState
                        .padding(.top, 6)
                } else if (selectedTab ?? .dashboard) == .logs {
                    loggingSection()
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
                showConfigurationDialog = true
            } label: {
                Label("Konfiguration", systemImage: "gearshape")
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
                        .tag(Optional(pane))
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 230)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedConfigDialogPane ?? .onDemandApps {
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

    private func dashboardSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Dashboard") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    dashboardStatusCard(
                        title: "Läuft Caddy?",
                        isPositive: snapshot.caddyRuntimeStatus.isRunning,
                        detail: snapshot.caddyRuntimeStatus.adminEndpoint,
                        color: snapshot.caddyRuntimeStatus.isRunning ? .green : .orange
                    )

                    dashboardStatusCard(
                        title: "Ist das Cert gültig?",
                        isPositive: isCertificateValid(snapshot),
                        detail: snapshot.tlsStatus.systemKeychainTrustStatus.label,
                        color: isCertificateValid(snapshot) ? .green : .orange
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    dashboardMetricCard(
                        title: "Caddy",
                        value: snapshot.caddyInstall.isInstalled ? "Installiert" : "Nicht installiert",
                        tone: snapshot.caddyInstall.isInstalled ? .green : .orange
                    )
                    dashboardMetricCard(
                        title: "Version",
                        value: snapshot.caddyInstall.version ?? "unknown",
                        isMonospaced: true
                    )
                    dashboardMetricCard(title: "Routen", value: "\(snapshot.configPreview.routeCount)")
                    dashboardMetricCard(title: "Targets", value: "\(snapshot.runtimeTargets.count)")
                }

                dashboardQuickAccessSection(snapshot)

                HStack {
                    Text("Snapshot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private func dashboardStatusCard(
        title: String,
        isPositive: Bool,
        detail: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityLabel(isPositive ? "Ja" : "Nein")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private func dashboardMetricCard(
        title: String,
        value: String,
        tone: Color = .accentColor,
        isMonospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .fontWeight(.semibold)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tone.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dashboardQuickAccessSection(_ snapshot: DashboardSnapshot) -> some View {
        let multipassTargets = snapshot.runtimeTargets.filter { target in
            target.source == .multipass && target.status.lowercased() == "running"
        }
        let podTargets = snapshot.runtimeTargets.filter { $0.source == .podman }

        if !multipassTargets.isEmpty || !podTargets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Access")
                    .font(.headline)

                if !multipassTargets.isEmpty {
                    dashboardRuntimeCardGroup(
                        title: "Multipass VMs",
                        icon: "shippingbox",
                        targets: multipassTargets
                    )
                }

                if !podTargets.isEmpty {
                    dashboardRuntimeCardGroup(
                        title: "Pods (Podman)",
                        icon: "square.stack.3d.up",
                        targets: podTargets
                    )
                }
            }
        }
    }

    private func dashboardRuntimeCardGroup(
        title: String,
        icon: String,
        targets: [RuntimeTarget]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title) (\(targets.count))", systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                ForEach(targets) { target in
                    dashboardRuntimeLinkCard(target)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func dashboardRuntimeLinkCard(_ target: RuntimeTarget) -> some View {
        let destination = runtimeDashboardURL(for: target)

        return Button {
            guard let destination else { return }
            openURL(destination)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(target.source == .multipass ? "Multipass VM" : "Podman Pod")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(destination == nil ? .tertiary : .secondary)
                }

                if let displayURL = runtimeDashboardURLDisplayString(for: target) {
                    Text(displayURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Kein Browser-Link verfügbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(target.status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(target.address)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(destination == nil)
    }

    @ViewBuilder
    private func warningSection(_ warnings: [String]) -> some View {
        if !warnings.isEmpty {
            GroupBox("Warnings") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                        Text("• \(warning)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func autoSetupSection(_ report: AutoSetupReport) -> some View {
        if report.attempted {
            GroupBox("Automatic Setup") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.operations) { operation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(operation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                Spacer()
                                Text(operation.succeeded ? "Success" : "Failed")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((operation.succeeded ? Color.green : Color.red).opacity(0.16))
                                    .foregroundStyle(operation.succeeded ? .green : .red)
                                    .clipShape(Capsule())
                            }
                            Text(operation.message)
                            if !operation.output.isEmpty {
                                Text(operation.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Text(operation.performedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func featureSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Feature Progress") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.features) { feature in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(feature.id) · \(feature.title)")
                                .font(.headline)
                            Text(feature.summary)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Text(feature.documentPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(feature.status.label)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(feature.status).opacity(0.16))
                            .foregroundStyle(statusColor(feature.status))
                            .clipShape(Capsule())
                    }
                    Divider()
                }
                Text("Last snapshot: \(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func systemSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Caddy / TLS") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Caddy installed") {
                    Text(snapshot.caddyInstall.isInstalled ? "Yes" : "No")
                }
                LabeledContent("Binary path") {
                    Text(snapshot.caddyInstall.binaryPath ?? "-")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Local version") {
                    Text(snapshot.caddyInstall.version ?? "unknown")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Latest release") {
                    if let latest = snapshot.latestRelease {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.tagName)
                            if let publishedAt = latest.publishedAt {
                                Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let url = latest.url {
                                Link(url.absoluteString, destination: url)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("Unavailable")
                    }
                }
                LabeledContent("Update command") {
                    Text(snapshot.caddyInstall.suggestedInstallCommand)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Update available") {
                    if !snapshot.caddyUpdateStatus.checked {
                        Text("Unknown (release check unavailable)")
                    } else {
                        if snapshot.caddyUpdateStatus.updateAvailable {
                            Text("Yes (new version available)")
                                .foregroundStyle(.orange)
                        } else {
                            Text("No (up to date)")
                                .foregroundStyle(.green)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button("Update Caddy") {
                        showCaddyUpdateConfirmation = true
                    }
                    .disabled(
                        !snapshot.caddyInstall.isInstalled
                        || !snapshot.caddyUpdateStatus.checked
                        || !snapshot.caddyUpdateStatus.updateAvailable
                    )

                    if viewModel.isUpdatingCaddy {
                        InlineActivitySkeleton()
                    }
                }
                if let updateOperation = viewModel.lastCaddyUpdateOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(updateOperation.message)
                            .foregroundStyle(updateOperation.succeeded ? .green : .red)
                        if let previous = updateOperation.previousVersion, let current = updateOperation.currentVersion {
                            Text("Version: \(previous) -> \(current)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if updateOperation.recoveryAttempted {
                            Text("Recovery attempted: \(updateOperation.recoverySucceeded == true ? "yes (success)" : "yes (failed)")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !updateOperation.output.isEmpty {
                            Text(updateOperation.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(updateOperation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Divider()
                LabeledContent("Caddy runtime") {
                    Text(snapshot.caddyRuntimeStatus.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(snapshot.caddyRuntimeStatus.isRunning ? .green : .secondary)
                }
                Toggle(
                    "Caddy einschalten",
                    isOn: Binding(
                        get: { viewModel.snapshot?.caddyRuntimeStatus.isRunning ?? false },
                        set: { viewModel.setCaddyRunning($0) }
                    )
                )
                .disabled(
                    !snapshot.caddyInstall.isInstalled
                    || viewModel.isChangingCaddyRuntime
                    || viewModel.isApplyingConfig
                )
                if viewModel.isChangingCaddyRuntime {
                    InlineActivitySkeleton()
                }
                LabeledContent("Root certificate") {
                    Text(snapshot.tlsStatus.rootCertificatePresent ? "Present" : "Missing")
                }
                LabeledContent("System Keychain trust") {
                    Text(snapshot.tlsStatus.systemKeychainTrustStatus.label)
                        .foregroundStyle(tlsTrustColor(snapshot.tlsStatus.systemKeychainTrustStatus))
                }
                LabeledContent("CA path") {
                    Text(snapshot.tlsStatus.localCARootPath)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Trust command") {
                    Text(snapshot.tlsStatus.caddyTrustCommand)
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 10) {
                    Button("Trust Root CA (macOS Dialog)") {
                        viewModel.trustLocalCA()
                    }
                    .disabled(!snapshot.caddyInstall.isInstalled)

                    if viewModel.isApplyingTLSTrust {
                        InlineActivitySkeleton()
                    }
                }
                if let trustOperation = viewModel.lastTrustOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trustOperation.message)
                            .foregroundStyle(trustOperation.succeeded ? .green : .red)
                        if !trustOperation.output.isEmpty {
                            Text(trustOperation.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(trustOperation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(snapshot.tlsStatus.systemKeychainTrustDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.tlsStatus.installHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func runtimeSection(_ snapshot: DashboardSnapshot) -> some View {
        let podmanTargets = snapshot.runtimeTargets.filter { $0.source == .podman }

        return VStack(alignment: .leading, spacing: 16) {
            GroupBox("Runtime Discovery (Podman)") {
                VStack(alignment: .leading, spacing: 8) {
                    if podmanTargets.isEmpty {
                        Text("Keine Podman Runtime Targets erkannt.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(podmanTargets) { target in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(target.name)
                                            .font(.headline)
                                        Text(target.source.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(target.address)
                                    .font(.system(.body, design: .monospaced))
                                Text(target.status)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }


    private func configSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Reverse Proxy Configuration Preview") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Managed routes") {
                    Text("\(snapshot.configPreview.routeCount)")
                }
                LabeledContent("Target Caddyfile") {
                    Text(snapshot.configPreview.caddyfilePath)
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 10) {
                    Button("Write Config") {
                        viewModel.writeConfigPreview()
                    }
                    Button("Validate") {
                        viewModel.validateConfigPreview()
                    }
                    Button("Reload Caddy") {
                        showReloadConfigConfirmation = true
                    }
                    .disabled(!snapshot.caddyInstall.isInstalled)

                    if viewModel.isApplyingConfig {
                        InlineActivitySkeleton()
                    }
                }
                .disabled(viewModel.isApplyingConfig || viewModel.isLoading || viewModel.isChangingCaddyRuntime)

                if let operation = viewModel.lastConfigOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(operation.kind.rawValue.capitalized): \(operation.message)")
                            .foregroundStyle(operation.succeeded ? .green : .red)
                        if !operation.output.isEmpty {
                            Text(operation.output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        Text(operation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                TextEditor(text: .constant(snapshot.configPreview.generatedCaddyfile))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
            }
            .padding(.top, 4)
        }
    }

    private func loggingSection() -> some View {
        let filteredLogText = filteredLogs(viewModel.appLogText, query: viewModel.logFilterQuery)

        return GroupBox("Logging / Debug") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enthält CLI-Kommandos (inkl. Exit-Code/Output) sowie Start/Stop-Ereignisse für Caddy und On-Demand-Apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Logs aktualisieren") {
                        viewModel.refreshLogs()
                    }
                    .disabled(viewModel.isRefreshingLogs)

                    Button("Logs leeren", role: .destructive) {
                        viewModel.clearLogs()
                    }

                    if viewModel.isRefreshingLogs {
                        InlineActivitySkeleton()
                    }

                    Spacer()

                    Text(AppPaths.appLogFile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    TextField("Filter (z. B. app=Grafana)", text: $viewModel.logFilterQuery)
                        .textFieldStyle(.roundedBorder)
                    if !viewModel.logFilterQuery.isEmpty {
                        Button("Filter löschen") {
                            viewModel.logFilterQuery = ""
                        }
                    }
                }

                if filteredLogText.isEmpty {
                    Text("Noch keine Logs vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    TextEditor(text: .constant(filteredLogText))
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 420)
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            viewModel.refreshLogs()
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

    private func filteredLogs(_ logText: String, query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return logText }
        let needle = trimmed.lowercased()
        return logText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.lowercased().contains(needle) }
            .joined(separator: "\n")
    }

    private func statusColor(_ status: FeatureStatus) -> Color {
        switch status {
        case .planned: return .gray
        case .inProgress: return .orange
        case .done: return .green
        case .blocked: return .red
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

    private func tlsTrustColor(_ status: CertificateTrustStatus) -> Color {
        switch status {
        case .trusted:
            return .green
        case .notTrusted:
            return .orange
        case .notChecked, .unknown:
            return .secondary
        }
    }

    private func isCertificateValid(_ snapshot: DashboardSnapshot) -> Bool {
        snapshot.tlsStatus.rootCertificatePresent
            && snapshot.tlsStatus.systemKeychainTrustStatus == .trusted
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

    private func runtimeDashboardURL(for target: RuntimeTarget) -> URL? {
        switch target.source {
        case .multipass:
            guard let host = multipassAutoHost(for: target.name) else { return nil }
            return URL(string: "https://\(host)")
        case .podman:
            if target.address.hasPrefix("http://") || target.address.hasPrefix("https://") {
                return URL(string: target.address)
            }

            let port = target.address.split(separator: ":").last.flatMap { Int($0) }
            let scheme = (port == 443 || port == 8443) ? "https" : "http"
            return URL(string: "\(scheme)://\(target.address)")
        case .manual:
            return nil
        case .onDemand:
            return nil
        case .multipassService:
            return nil
        }
    }

    private func runtimeDashboardURLDisplayString(for target: RuntimeTarget) -> String? {
        runtimeDashboardURL(for: target)?.absoluteString
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
