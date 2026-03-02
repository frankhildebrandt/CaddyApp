import SwiftUI

extension ContentView {
    func multipassSection(_ snapshot: DashboardSnapshot) -> some View {
        let multipassTargets = snapshot.runtimeTargets.filter { $0.source == .multipass }
        let targetByName = Dictionary(uniqueKeysWithValues: multipassTargets.map { ($0.name, $0) })
        let statusesByID = Dictionary(uniqueKeysWithValues: snapshot.multipassServiceStatuses.map { ($0.id, $0) })
        let servicesByVM = Dictionary(grouping: Array(viewModel.multipassServices.indices), by: { index in
            let name = viewModel.multipassServices[index].vmName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Unzugeordnet" : name
        })
        var vmNames = Set(multipassTargets.map(\.name))
        vmNames.formUnion(servicesByVM.keys.filter { $0 != "Unzugeordnet" })
        let sortedVMNames = vmNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let unassignedServiceIndices = servicesByVM["Unzugeordnet"] ?? []

        return VStack(alignment: .leading, spacing: 16) {
            GroupBox("Multipass VMs") {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedVMNames.isEmpty {
                        Text("Keine Multipass VMs erkannt.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 12)], spacing: 12) {
                            ForEach(sortedVMNames, id: \.self) { vmName in
                                multipassVMCard(
                                    vmName: vmName,
                                    target: targetByName[vmName],
                                    serviceIndices: servicesByVM[vmName] ?? [],
                                    statusesByID: statusesByID
                                )
                            }
                        }
                    }

                    if !unassignedServiceIndices.isEmpty {
                        GroupBox("Nicht zugeordnete Services") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diese Services haben keinen VM-Namen. Bitte VM setzen.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(unassignedServiceIndices, id: \.self) { index in
                                    multipassServiceRow(at: index, vmName: nil, statusesByID: statusesByID)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    if let result = viewModel.lastMultipassVMControlResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.succeeded ? .green : .red)
                            .lineLimit(2)
                    }

                    if let result = viewModel.lastMultipassServiceControlResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.succeeded ? .green : .red)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    func multipassVMCard(
        vmName: String,
        target: RuntimeTarget?,
        serviceIndices: [Int],
        statusesByID: [UUID: MultipassServiceRuntimeStatus]
    ) -> some View {
        let vmState = target?.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        let canStart = vmState == "stopped"
        let canStop = vmState == "running"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(vmName, systemImage: "shippingbox.fill")
                        .font(.headline)
                    Text(target?.address ?? "(no ip)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let host = multipassAutoHost(for: vmName) {
                        Text("Auto route: \(host)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(target?.status ?? "unknown")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                if canStart {
                    Button {
                        viewModel.controlMultipassVM(vmName: vmName, action: .start)
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.isChangingMultipassVMRuntime || viewModel.isChangingMultipassServiceRuntime)
                }

                if canStop {
                    Button {
                        viewModel.controlMultipassVM(vmName: vmName, action: .stop)
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isChangingMultipassVMRuntime || viewModel.isChangingMultipassServiceRuntime)

                    Button(role: .destructive) {
                        viewModel.controlMultipassVM(vmName: vmName, action: .forceStop)
                    } label: {
                        Label("Force-Stop", systemImage: "exclamationmark.octagon.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isChangingMultipassVMRuntime || viewModel.isChangingMultipassServiceRuntime)
                }

                Spacer()

                Button {
                    viewModel.addMultipassService(forVMName: vmName)
                } label: {
                    Label("Service hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            if serviceIndices.isEmpty {
                Text("Noch keine Services für diese VM konfiguriert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(serviceIndices, id: \.self) { index in
                    multipassServiceRow(at: index, vmName: vmName, statusesByID: statusesByID)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    func customConfigSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Custom Routes") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Eigene Hosts werden mit den automatisch erkannten Runtime-Routen kombiniert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Traefik.me-Aliase fuer .localhost-Hosts aktivieren", isOn: $viewModel.enableTraefikMeAliases)
                        .toggleStyle(.checkbox)
                    Text("Erzeugt pro Host zusaetzliche Aliase wie <host>.<ip>.traefik.me (nur fuer nicht-Wildcard .localhost-Hosts).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if viewModel.customRoutes.isEmpty {
                        Text("Noch keine Custom Route angelegt.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(viewModel.customRoutes.indices), id: \.self) { index in
                                customRouteRow(at: index)
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
                            InlineActivitySkeleton()
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

    func customRouteRow(at index: Int) -> some View {
        let routeBinding = $viewModel.customRoutes[index]
        let routeID = routeBinding.wrappedValue.id

        return HStack(alignment: .center, spacing: 8) {
            Toggle("", isOn: routeBinding.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            TextField("Host (z. B. app.localhost)", text: routeBinding.host)
                .textFieldStyle(.roundedBorder)

            Text("->")
                .foregroundStyle(.secondary)

            TextField("Upstream (z. B. 127.0.0.1:3000)", text: routeBinding.upstream)
                .textFieldStyle(.roundedBorder)

            Button(role: .destructive) {
                viewModel.removeCustomRoute(id: routeID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Route entfernen")
        }
    }

    func multipassServiceRow(
        at index: Int,
        vmName: String?,
        statusesByID: [UUID: MultipassServiceRuntimeStatus]
    ) -> some View {
        let serviceBinding = $viewModel.multipassServices[index]
        let serviceID = serviceBinding.wrappedValue.id
        let runtimeStatus = statusesByID[serviceID]

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: serviceBinding.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                if let vmName {
                    Text(vmName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Capsule())
                } else {
                    TextField("VM", text: serviceBinding.vmName)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Service", text: serviceBinding.serviceName)
                    .textFieldStyle(.roundedBorder)
                TextField("Host", text: serviceBinding.host)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                TextField("Port", value: serviceBinding.targetPort, formatter: integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Picker("Scheme", selection: serviceBinding.scheme) {
                    Text("http").tag(MultipassServiceScheme.http)
                    Text("https").tag(MultipassServiceScheme.https)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                Toggle("AutoStart VM", isOn: serviceBinding.autoStartVM)
                    .toggleStyle(.checkbox)
                Toggle("AutoStop VM", isOn: serviceBinding.autoStopVM)
                    .toggleStyle(.checkbox)
                TextField("Idle s", value: serviceBinding.idleTimeoutSeconds, formatter: integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }
            HStack {
                TextField("systemd unit (optional)", text: serviceBinding.systemdUnit)
                    .textFieldStyle(.roundedBorder)
                Toggle("AutoStart systemd", isOn: serviceBinding.autoStartSystemd)
                    .toggleStyle(.checkbox)
                Toggle("AutoStop systemd", isOn: serviceBinding.autoStopSystemd)
                    .toggleStyle(.checkbox)
            }
            HStack {
                if let runtimeStatus {
                    Text("VM: \(runtimeStatus.vmStatus) • systemd: \(runtimeStatus.systemdStatus) • phase: \(runtimeStatus.phase.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    viewModel.controlMultipassService(serviceID: serviceID, action: .start)
                } label: {
                    Label("Start", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.isChangingMultipassServiceRuntime)
                Button {
                    viewModel.controlMultipassService(serviceID: serviceID, action: .stop)
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.isChangingMultipassServiceRuntime)
                if !serviceBinding.wrappedValue.systemdUnit.isEmpty {
                    Button {
                        viewModel.controlMultipassService(serviceID: serviceID, action: .startSystemd)
                    } label: {
                        Label("Start unit", systemImage: "bolt.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isChangingMultipassServiceRuntime)
                    Button {
                        viewModel.controlMultipassService(serviceID: serviceID, action: .restartSystemd)
                    } label: {
                        Label("Restart unit", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isChangingMultipassServiceRuntime)
                    Button {
                        viewModel.controlMultipassService(serviceID: serviceID, action: .stopSystemd)
                    } label: {
                        Label("Stop unit", systemImage: "power.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isChangingMultipassServiceRuntime)
                }
                Button(role: .destructive) {
                    viewModel.removeMultipassService(id: serviceID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Divider()
        }
        .onAppear {
            guard let vmName else { return }
            if serviceBinding.wrappedValue.vmName != vmName {
                serviceBinding.wrappedValue.vmName = vmName
            }
        }
    }

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
