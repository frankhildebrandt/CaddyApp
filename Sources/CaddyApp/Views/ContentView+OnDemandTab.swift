import SwiftUI

extension ContentView {
    func appRepositoryRow(at index: Int) -> some View {
        let repositoryBinding = $viewModel.appRepositories[index]
        let repositoryID = repositoryBinding.wrappedValue.id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: repositoryBinding.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                TextField("Repository-Name", text: repositoryBinding.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                TextField("Repository-URL", text: repositoryBinding.entryURL)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.moveAppRepositoryUp(id: repositoryID)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                Button {
                    viewModel.moveAppRepositoryDown(id: repositoryID)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    viewModel.removeAppRepository(id: repositoryID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    func onDemandAppsSection(_ snapshot: DashboardSnapshot) -> some View {
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

    func movedToConfigurationDialogView(
        title: String,
        description: String,
        pane: ConfigDialogPane
    ) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                Text(description)
                    .foregroundStyle(.secondary)
                Button {
                    selectedConfigDialogPane = pane
                    showConfigurationDialog = true
                } label: {
                    Label("Im Konfigurationsdialog öffnen", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
    }

    func onDemandAppDetail(
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

    func onDemandAppEditor(app: Binding<OnDemandAppDraft>) -> some View {
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

    func onDemandHostLogView(app: OnDemandAppDraft) -> some View {
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

    func onDemandContainerLogView(app: OnDemandAppDraft) -> some View {
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
                InlineActivitySkeleton()
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

    func onDemandShellView(app: OnDemandAppDraft) -> some View {
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

    func onDemandEventLogView(app: OnDemandAppDraft) -> some View {
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

    func loadOnDemandSubTab(tab: OnDemandSubTab, app: OnDemandAppDraft) {
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

    func refreshOnDemandContainerLog(app: OnDemandAppDraft) {
        onDemandLoadingByAppID[app.id] = true
        Task {
            let text = await viewModel.fetchContainerLogText(for: app, tailLines: 200)
            onDemandContainerLogByAppID[app.id] = text
            onDemandLoadingByAppID[app.id] = false
        }
    }

    func bindingForOnDemandApp(id: UUID) -> Binding<OnDemandAppDraft>? {
        guard let index = viewModel.onDemandApps.firstIndex(where: { $0.id == id }) else { return nil }
        return $viewModel.onDemandApps[index]
    }

    func removeOnDemandAppAndUpdateSelection(id: UUID) {
        viewModel.removeOnDemandApp(id: id)

        if selectedOnDemandAppID == id {
            selectedOnDemandAppID = nil
        }
    }

    var onDemandPresetPickerSheet: some View {
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

                            ForEach(Array(viewModel.appRepositories.indices), id: \.self) { index in
                                appRepositoryRow(at: index)
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
                                    InlineActivitySkeleton()
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

    func onDemandAddOptionTile(
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
}
