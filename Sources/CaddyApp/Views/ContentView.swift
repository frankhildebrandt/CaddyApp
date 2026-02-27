import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    private enum OnDemandSubTab: String, CaseIterable, Identifiable {
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
        case onDemandApps = "on_demand_apps"
        case custom
        case config
        case logs
        case features

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .caddyTLS: return "Caddy / TLS"
            case .runtime: return "Runtime"
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
            case .onDemandApps: return "bolt.badge.clock"
            case .custom: return "slider.horizontal.3"
            case .config: return "doc.text"
            case .logs: return "terminal"
            case .features: return "list.bullet.clipboard"
            }
        }
    }

    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var onDemandShellSession = OnDemandEmbeddedShellSession()
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false
    @State private var showCaddyUpdateConfirmation = false
    @State private var showReloadConfigConfirmation = false
    @State private var selectedTab: SidebarTab? = .dashboard
    @State private var selectedOnDemandAppID: UUID?
    @State private var selectedOnDemandSubTab: OnDemandSubTab = .config
    @State private var showOnDemandPresetPicker = false
    @State private var onDemandShellInput = ""
    @State private var onDemandHostLogByAppID: [UUID: String] = [:]
    @State private var onDemandContainerLogByAppID: [UUID: String] = [:]
    @State private var onDemandEventLogByAppID: [UUID: String] = [:]
    @State private var onDemandLoadingByAppID: [UUID: Bool] = [:]

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
        .onChange(of: viewModel.appRepositories) { _, _ in
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
                    case .onDemandApps:
                        onDemandAppsSection(snapshot)
                    case .custom:
                        customConfigSection(snapshot)
                    case .config:
                        configSection(snapshot)
                    case .logs:
                        loggingSection()
                    case .features:
                        featureSection(snapshot)
                    }
                } else if viewModel.isLoading {
                    ProgressView("Loading local environment...")
                        .padding(.top, 24)
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
                    Text("macOS control panel for Caddy, localhost reverse proxies, AutoTLS and runtime discovery")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("In Menüleiste") {
                AppWindowController().hideAppToMenuBar()
            }
            .buttonStyle(.bordered)
            Toggle("Schließen versteckt", isOn: $hideWindowToMenuBarOnClose)
                .toggleStyle(.checkbox)
            Button(viewModel.isLoading ? "Refreshing..." : "Refresh") {
                viewModel.refresh()
            }
            .disabled(viewModel.isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
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
                        ProgressView()
                            .controlSize(.small)
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
                    ProgressView()
                        .controlSize(.small)
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
                        ProgressView()
                            .controlSize(.small)
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
        GroupBox("Runtime Discovery (Multipass / Podman)") {
            VStack(alignment: .leading, spacing: 8) {
                if snapshot.runtimeTargets.isEmpty {
                    Text("No runtime targets detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.runtimeTargets) { target in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(target.name)
                                        .font(.headline)
                                    Text(target.source.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if target.source == .multipass, let host = multipassAutoHost(for: target.name) {
                                    Text("Auto route: \(host)")
                                        .font(.caption.monospaced())
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

    private func customConfigSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Custom Routes") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Eigene Hosts werden mit den automatisch erkannten Runtime-Routen kombiniert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.customRoutes.isEmpty {
                        Text("Noch keine Custom Route angelegt.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach($viewModel.customRoutes) { $route in
                                HStack(alignment: .center, spacing: 8) {
                                    Toggle("", isOn: $route.enabled)
                                        .labelsHidden()
                                        .toggleStyle(.checkbox)

                                    TextField("Host (z. B. app.localhost)", text: $route.host)
                                        .textFieldStyle(.roundedBorder)

                                    Text("->")
                                        .foregroundStyle(.secondary)

                                    TextField("Upstream (z. B. 127.0.0.1:3000)", text: $route.upstream)
                                        .textFieldStyle(.roundedBorder)

                                    Button(role: .destructive) {
                                        viewModel.removeCustomRoute(id: route.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Route entfernen")
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Route hinzufügen") {
                            viewModel.addCustomRoute()
                        }
                        Spacer()
                        Text("Aktive Routen im Preview: \(snapshot.configPreview.routeCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Zusätzliche Caddyfile-Config") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optionaler Caddyfile-Block, der an die generierte Konfiguration angehängt wird.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.customAdditionalCaddyfileConfig)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 160)

                        if viewModel.customAdditionalCaddyfileConfig.isEmpty {
                            Text("# Beispiel\n# my.internal {\n#     respond \"hello\" 200\n# }")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Custom Config speichern") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Routes und On-Demand Apps werden automatisch gespeichert und direkt angewendet. Dieser Button ist nur für den zusätzlichen Caddyfile-Block.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Custom Config speichern") {
                            viewModel.saveAdditionalCaddyfileConfig()
                        }
                        .disabled(viewModel.isSavingCustomConfig || viewModel.isLoading || viewModel.isChangingCaddyRuntime)

                        if viewModel.isSavingCustomConfig {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let validationError = viewModel.customConfigValidationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                    }

                    if let saveResult = viewModel.lastCustomConfigSaveResult {
                        Text(saveResult.message)
                            .foregroundStyle(saveResult.succeeded ? .green : .red)
                        Text(saveResult.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let operation = viewModel.lastConfigOperation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Letzte Config-Aktion: \(operation.kind.rawValue.capitalized) - \(operation.message)")
                                .foregroundStyle(operation.succeeded ? .green : .red)
                            if !operation.output.isEmpty {
                                Text(operation.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 4)
            }
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
                        if selectedOnDemandAppID != nil {
                            Button {
                                onDemandShellSession.stop()
                                selectedOnDemandAppID = nil
                            } label: {
                                Label("Zurück zur Liste", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            viewModel.refreshAppRepositoryPresets()
                        } label: {
                            Label("Web-Update", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isRefreshingAppRepositories)
                        Button {
                            showOnDemandPresetPicker = true
                        } label: {
                            Label("Hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if viewModel.onDemandApps.isEmpty {
                        Text("Noch keine On-Demand-App angelegt.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else if let selectedID = selectedOnDemandAppID,
                              let appBinding = bindingForOnDemandApp(id: selectedID)
                    {
                        let app = appBinding.wrappedValue
                        let runtimeStatus = statusesByID[selectedID]
                        onDemandAppDetail(
                            app: appBinding,
                            runtimeStatus: runtimeStatus
                        )
                        .onAppear {
                            loadOnDemandSubTab(tab: selectedOnDemandSubTab, app: app)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.onDemandApps) { app in
                                let runtimeStatus = statusesByID[app.id]
                                Button {
                                    selectedOnDemandAppID = app.id
                                    selectedOnDemandSubTab = .config
                                    loadOnDemandSubTab(tab: .config, app: app)
                                } label: {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(
                                                app.enabled
                                                    ? onDemandPhaseColor(runtimeStatus?.phase ?? .stopped)
                                                    : .secondary
                                            )
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(app.name.isEmpty ? "Neue App" : app.name)
                                                    .font(.headline)
                                                Text(app.runtime.label)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(app.unitKind.label)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text("https://\(app.host)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                            Text("\(app.targetHost):\(app.targetPort) • idle \(app.idleTimeoutSeconds)s")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Änderungen werden automatisch gespeichert und bei gültiger Konfiguration direkt auf Caddy angewendet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let validationError = viewModel.customConfigValidationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                    }
                    if let saveResult = viewModel.lastCustomConfigSaveResult {
                        Text(saveResult.message)
                            .foregroundStyle(saveResult.succeeded ? .green : .red)
                            .font(.caption)
                    }
                    if let controlResult = viewModel.lastOnDemandAppControlResult {
                        Text(controlResult.message)
                            .foregroundStyle(controlResult.succeeded ? .green : .red)
                            .font(.caption)
                    }
                    if let repositoryResult = viewModel.lastRepositorySyncResult {
                        Text(repositoryResult.message)
                            .foregroundStyle(repositoryResult.succeeded ? .green : .red)
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func onDemandAppDetail(
        app: Binding<OnDemandAppDraft>,
        runtimeStatus: OnDemandAppRuntimeStatus?
    ) -> some View {
        let appID = app.wrappedValue.id
        let phase = runtimeStatus?.phase ?? .stopped
        let isEnabled = app.wrappedValue.enabled

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.wrappedValue.name.isEmpty ? "Neue App" : app.wrappedValue.name)
                            .font(.headline)
                        Text(app.wrappedValue.runtime.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(app.wrappedValue.unitKind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("https://\(app.wrappedValue.host.isEmpty ? "host.localhost" : app.wrappedValue.host)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("\(app.wrappedValue.targetHost):\(app.wrappedValue.targetPort) • idle \(app.wrappedValue.idleTimeoutSeconds)s • gateway \(OnDemandAppsService.gatewayPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastAccessAt = runtimeStatus?.lastAccessAt {
                        Text("Letzter Zugriff: \(lastAccessAt.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let lastError = runtimeStatus?.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(isEnabled ? phase.label : "Disabled")
                        .foregroundStyle(isEnabled ? onDemandPhaseColor(phase) : .secondary)

                    HStack(spacing: 6) {
                        if isEnabled {
                            Button {
                                viewModel.setOnDemandAppRunning(
                                    appID: appID,
                                    shouldRun: phase != .running
                                )
                            } label: {
                                Image(systemName: phase == .running ? "stop.fill" : "play.fill")
                                    .frame(width: 14, height: 14)
                            }
                            .help(phase == .running ? "Stop" : "Start")
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isChangingOnDemandAppRuntime)
                        }

                        Button("Löschen", role: .destructive) {
                            removeOnDemandAppAndUpdateSelection(id: appID)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    }
                }
            }

            Picker("Sub-Tab", selection: $selectedOnDemandSubTab) {
                ForEach(OnDemandSubTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedOnDemandSubTab) { oldTab, newTab in
                if oldTab == .shell, newTab != .shell {
                    onDemandShellSession.stop()
                }
                loadOnDemandSubTab(tab: newTab, app: app.wrappedValue)
            }

            switch selectedOnDemandSubTab {
            case .config:
                onDemandAppEditor(app: app)
            case .hostLog:
                onDemandHostLogView(app: app.wrappedValue)
            case .containerLog:
                onDemandContainerLogView(app: app.wrappedValue)
            case .shell:
                onDemandShellView(app: app.wrappedValue)
            case .eventLog:
                onDemandEventLogView(app: app.wrappedValue)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func onDemandAppEditor(app: Binding<OnDemandAppDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle("Aktiv", isOn: app.enabled)
                    .toggleStyle(.checkbox)
                TextField("Name", text: app.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Host (z. B. grafana.localhost)", text: app.host)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) {
                    removeOnDemandAppAndUpdateSelection(id: app.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Picker("Runtime", selection: app.runtime) {
                    ForEach(ContainerRuntimeKind.allCases, id: \.self) { runtime in
                        Text(runtime.label).tag(runtime)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Picker("Unit", selection: app.unitKind) {
                    ForEach(ContainerUnitKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                TextField("Container/Pod Name", text: app.unitName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                TextField("Target Host", text: app.targetHost)
                    .textFieldStyle(.roundedBorder)
                TextField("Target Port", value: app.targetPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Idle (s)", value: app.idleTimeoutSeconds, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Health Path", text: app.healthPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }

            HStack(spacing: 8) {
                Picker("Start", selection: app.startMode) {
                    ForEach(OnDemandStartMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Text("Gateway: 127.0.0.1:\(OnDemandAppsService.gatewayPort)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            TextField(
                "Run Arguments (z. B. run -d --name myapp -p 3000:3000 image:tag)",
                text: app.runArguments
            )
            .textFieldStyle(.roundedBorder)
            .disabled(app.wrappedValue.startMode != .runCommand)

            Text("Bei 'Run Command' wird entweder `<runtime> <runArguments>` (falls gesetzt) oder eine Preset-Run-Step-Sequenz ausgeführt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func onDemandHostLogView(app: OnDemandAppDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Gefilterte Host-Logs aus dem App-Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aktualisieren") {
                    onDemandHostLogByAppID[app.id] = viewModel.hostLogText(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            let text = onDemandHostLogByAppID[app.id] ?? ""
            if text.isEmpty {
                Text("Keine passenden Host-Log-Zeilen gefunden.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
            }
        }
    }

    private func onDemandContainerLogView(app: OnDemandAppDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Container/Pod-Logs (\(app.runtime.label))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aktualisieren") {
                    refreshOnDemandContainerLog(app: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(onDemandLoadingByAppID[app.id] == true)
            }

            if onDemandLoadingByAppID[app.id] == true {
                ProgressView()
                    .controlSize(.small)
            }

            let text = onDemandContainerLogByAppID[app.id] ?? ""
            if text.isEmpty {
                Text("Noch keine Container/Pod-Logs geladen.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
            }
        }
    }

    private func onDemandShellView(app: OnDemandAppDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(onDemandShellSession.statusMessage.isEmpty ? "Shell in der App" : onDemandShellSession.statusMessage)
                    .font(.caption)
                    .foregroundStyle(onDemandShellSession.isRunning ? .green : .secondary)
                Spacer()
                Button("Neu verbinden") {
                    onDemandShellSession.restart(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Interaktive Shell direkt im Tab (kein externes Terminal).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Befehl eingeben", text: $onDemandShellInput)
                    .textFieldStyle(.roundedBorder)
                Button("Senden") {
                    let command = onDemandShellInput
                    onDemandShellInput = ""
                    onDemandShellSession.send(command)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!onDemandShellSession.isRunning)
            }

            let output = onDemandShellSession.output
            if output.isEmpty {
                Text("Shell wird initialisiert...")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(output))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 260)
            }
        }
    }

    private func onDemandEventLogView(app: OnDemandAppDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Eventlog (Create, Start, Stop, Backup, ...)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aktualisieren") {
                    onDemandEventLogByAppID[app.id] = viewModel.eventLogText(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            let text = onDemandEventLogByAppID[app.id] ?? ""
            if text.isEmpty {
                Text("Keine passenden Event-Zeilen gefunden.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
            }
        }
    }

    private func loadOnDemandSubTab(tab: OnDemandSubTab, app: OnDemandAppDraft) {
        switch tab {
        case .config:
            break
        case .hostLog:
            onDemandHostLogByAppID[app.id] = viewModel.hostLogText(for: app)
        case .containerLog:
            if onDemandContainerLogByAppID[app.id] == nil {
                refreshOnDemandContainerLog(app: app)
            }
        case .shell:
            onDemandShellInput = ""
            onDemandShellSession.restart(for: app)
        case .eventLog:
            onDemandEventLogByAppID[app.id] = viewModel.eventLogText(for: app)
        }
    }

    private func refreshOnDemandContainerLog(app: OnDemandAppDraft) {
        onDemandLoadingByAppID[app.id] = true
        Task {
            let text = await viewModel.fetchContainerLogText(for: app, tailLines: 200)
            onDemandContainerLogByAppID[app.id] = text
            onDemandLoadingByAppID[app.id] = false
        }
    }

    private func bindingForOnDemandApp(id: UUID) -> Binding<OnDemandAppDraft>? {
        guard let index = viewModel.onDemandApps.firstIndex(where: { $0.id == id }) else { return nil }
        return $viewModel.onDemandApps[index]
    }

    private func removeOnDemandAppAndUpdateSelection(id: UUID) {
        viewModel.removeOnDemandApp(id: id)

        if selectedOnDemandAppID == id {
            selectedOnDemandAppID = nil
        }
    }

    private var onDemandPresetPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Wähle eine Vorlage oder lege eine Custom App an. Danach erscheint die App in der Übersichtsliste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    GroupBox("Repository-Quellen (YAML, Web)") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trage hier Web-Repositories ein (`repositories.yaml` oder `apps/index.yaml`) und lade Presets per Web-Update.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach($viewModel.appRepositories) { $repository in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Toggle("", isOn: $repository.enabled)
                                            .labelsHidden()
                                            .toggleStyle(.checkbox)
                                        TextField("Repository-Name", text: $repository.name)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: 220)
                                        TextField("Repository-URL", text: $repository.entryURL)
                                            .textFieldStyle(.roundedBorder)
                                        Button {
                                            viewModel.moveAppRepositoryUp(id: repository.id)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .buttonStyle(.borderless)
                                        Button {
                                            viewModel.moveAppRepositoryDown(id: repository.id)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .buttonStyle(.borderless)
                                        Button(role: .destructive) {
                                            viewModel.removeAppRepository(id: repository.id)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                Button {
                                    viewModel.addAppRepository()
                                } label: {
                                    Label("Repository hinzufügen", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    viewModel.refreshAppRepositoryPresets()
                                } label: {
                                    Label("Web-Repositories aktualisieren", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isRefreshingAppRepositories)

                                if viewModel.isRefreshingAppRepositories {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            if let result = viewModel.lastRepositorySyncResult {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.message)
                                        .foregroundStyle(result.succeeded ? .green : .red)
                                        .font(.caption)
                                    Text("Presets: \(result.loadedPresetCount) • Quellen: \(result.loadedRepositoryCount) • \(result.performedAt.formatted(date: .abbreviated, time: .standard))")
                                        .foregroundStyle(.secondary)
                                        .font(.caption2)
                                    if !result.warnings.isEmpty {
                                        ForEach(Array(result.warnings.prefix(3).enumerated()), id: \.offset) { _, warning in
                                            Text("• \(warning)")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    let columns = [
                        GridItem(.adaptive(minimum: 220), spacing: 12)
                    ]

                    Text("Lokale Presets")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: columns, spacing: 12) {
                        onDemandAddOptionTile(
                            title: "Custom App",
                            iconSystemName: "slider.horizontal.3",
                            summary: "Leere On-Demand-App mit eigener Runtime/Start-Konfiguration.",
                            meta: "Podman/Docker • frei konfigurierbar"
                        ) {
                            viewModel.addOnDemandApp()
                            selectedOnDemandAppID = nil
                            showOnDemandPresetPicker = false
                        }

                        ForEach(OnDemandAppPresetCatalog.all) { preset in
                            onDemandAddOptionTile(
                                title: preset.title,
                                iconSystemName: preset.iconSystemName,
                                summary: preset.summary,
                                meta: "\(preset.app.runtime.label) • \(preset.app.host) • Port \(preset.app.targetPort)"
                            ) {
                                viewModel.addOnDemandPreset(preset)
                                selectedOnDemandAppID = nil
                                showOnDemandPresetPicker = false
                            }
                        }
                    }

                    if !viewModel.remoteOnDemandPresets.isEmpty {
                        Text("Repository Presets")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.remoteOnDemandPresets) { preset in
                                onDemandAddOptionTile(
                                    title: preset.title,
                                    iconSystemName: preset.iconSystemName,
                                    summary: preset.summary,
                                    meta: "\(preset.app.runtime.label) • \(preset.app.host) • Port \(preset.app.targetPort)"
                                ) {
                                    viewModel.addOnDemandPreset(preset)
                                    selectedOnDemandAppID = nil
                                    showOnDemandPresetPicker = false
                                }
                            }
                        }
                    } else {
                        Text("Noch keine Repository-Presets geladen. Nutze 'Web-Repositories aktualisieren'.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Hinweis: Kimai und Ephe benötigen meist einen längeren ersten Start. Ephe wird aus dem Git-Repository im Container gebaut.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("On-Demand App hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        showOnDemandPresetPicker = false
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private func onDemandAddOptionTile(
        title: String,
        iconSystemName: String,
        summary: String,
        meta: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: iconSystemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(meta)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                        ProgressView()
                            .controlSize(.small)
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
                        ProgressView()
                            .controlSize(.small)
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

    private func onDemandPhaseColor(_ phase: OnDemandAppPhase) -> Color {
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

    private func multipassAutoHost(for name: String) -> String? {
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
        }
    }

    private func runtimeDashboardURLDisplayString(for target: RuntimeTarget) -> String? {
        runtimeDashboardURL(for: target)?.absoluteString
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
