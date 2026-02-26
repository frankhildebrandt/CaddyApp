import SwiftUI

struct ContentView: View {
    private enum SidebarTab: String, CaseIterable, Identifiable {
        case dashboard
        case caddyTLS = "caddy_tls"
        case runtime
        case custom
        case config
        case features

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .caddyTLS: return "Caddy / TLS"
            case .runtime: return "Runtime"
            case .custom: return "Custom"
            case .config: return "Config"
            case .features: return "Features"
            }
        }

        var systemImage: String {
            switch self {
            case .dashboard: return "rectangle.grid.2x2"
            case .caddyTLS: return "lock.shield"
            case .runtime: return "server.rack"
            case .custom: return "slider.horizontal.3"
            case .config: return "doc.text"
            case .features: return "list.bullet.clipboard"
            }
        }
    }

    @ObservedObject var viewModel: DashboardViewModel
    @AppStorage(AppWindowController.hideOnClosePreferenceKey) private var hideWindowToMenuBarOnClose = false
    @State private var showCaddyUpdateConfirmation = false
    @State private var showReloadConfigConfirmation = false
    @State private var selectedTab: SidebarTab? = .dashboard

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
        .background(MainWindowDelegateInstaller())
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
                    case .custom:
                        customConfigSection(snapshot)
                    case .config:
                        configSection(snapshot)
                    case .features:
                        featureSection(snapshot)
                    }
                } else if viewModel.isLoading {
                    ProgressView("Loading local environment...")
                        .padding(.top, 24)
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
                        .font(.largeTitle.bold())
                    Text("macOS control panel for Caddy, localhost reverse proxies, AutoTLS and runtime discovery")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("In Menüleiste") {
                AppWindowController().hideAppToMenuBar()
            }
            Toggle("Schließen versteckt", isOn: $hideWindowToMenuBarOnClose)
                .toggleStyle(.checkbox)
            Button(viewModel.isLoading ? "Refreshing..." : "Refresh") {
                viewModel.refresh()
            }
            .disabled(viewModel.isLoading)
        }
        .padding(20)
    }

    private func dashboardSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Dashboard") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
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

                Divider()

                LabeledContent("Caddy installiert") {
                    Text(snapshot.caddyInstall.isInstalled ? "Ja" : "Nein")
                }
                LabeledContent("Version") {
                    Text(snapshot.caddyInstall.version ?? "unknown")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Routen") {
                    Text("\(snapshot.configPreview.routeCount)")
                }
                LabeledContent("Runtime Targets") {
                    Text("\(snapshot.runtimeTargets.count)")
                }
                LabeledContent("Snapshot") {
                    Text(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))
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
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                if target.source == .multipass, let hosts = multipassAutoHosts(for: target.name) {
                                    Text("Auto routes: \(hosts.apex), \(hosts.wildcard)")
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

            GroupBox("Speichern & Anwenden") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speichert lokal unter Application Support. Danach wird ein Refresh ausgelöst; bei gültiger Konfiguration erfolgt der Auto-Reload automatisch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Speichern") {
                            viewModel.saveCustomConfig()
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

    private func statusColor(_ status: FeatureStatus) -> Color {
        switch status {
        case .planned: return .gray
        case .inProgress: return .orange
        case .done: return .green
        case .blocked: return .red
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

    private func multipassAutoHosts(for name: String) -> (apex: String, wildcard: String)? {
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
        return ("\(truncated).mp.localhost", "*.\(truncated).mp.localhost")
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
