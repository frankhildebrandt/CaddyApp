import SwiftUI

struct SettingsServicesPaneView: View {
    private struct ServiceEditorContext: Identifiable {
        let id = UUID()
        let sourceService: MultipassServiceDraft
        let existingService: MultipassServiceDraft?
        let isDiscoveredSource: Bool
    }

    let snapshot: DashboardSnapshot?
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var multipassViewModel: MultipassViewModel
    @State private var serviceEditorContext: ServiceEditorContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot {
                    multipassSection(snapshot)
                } else {
                    AppSkeletonView()
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(item: $serviceEditorContext) { context in
            MultipassServiceDetailView(
                sourceService: context.sourceService,
                existingService: context.existingService,
                isDiscoveredSource: context.isDiscoveredSource,
                dashboardViewModel: dashboardViewModel,
                multipassViewModel: multipassViewModel
            )
        }
    }

    private func multipassSection(_ snapshot: DashboardSnapshot) -> some View {
        let multipassTargets = snapshot.runtimeTargets.filter { $0.source == .multipass }
        let targetByName = Dictionary(uniqueKeysWithValues: multipassTargets.map { ($0.name, $0) })
        let statusesByID = Dictionary(uniqueKeysWithValues: snapshot.multipassServiceStatuses.map { ($0.id, $0) })
        let discoveredByVM = Dictionary(grouping: snapshot.discoveredMultipassServices, by: serviceVMGroupKey)
        let configuredByVM = Dictionary(grouping: dashboardViewModel.multipassServices, by: serviceVMGroupKey)

        var vmNames = Set(multipassTargets.map(\.name))
        vmNames.formUnion(configuredByVM.keys.filter { $0 != "Unzugeordnet" })
        vmNames.formUnion(discoveredByVM.keys.filter { $0 != "Unzugeordnet" })

        let sortedVMNames = vmNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let unassignedConfigured = configuredByVM["Unzugeordnet"] ?? []
        let unassignedDiscovered = discoveredByVM["Unzugeordnet"] ?? []

        return VStack(alignment: .leading, spacing: 16) {
            GroupBox("Service-Assistent") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lege VM-Services in wenigen Schritten an. Host und Standardwerte werden automatisch vorgeschlagen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    assistantRow(vmNames: sortedVMNames)

                    HStack(spacing: 10) {
                        Button {
                            if multipassViewModel.assistant.vmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                multipassViewModel.assistant.vmName = sortedVMNames.first ?? ""
                            }
                            multipassViewModel.prepareAssistant(
                                defaultVMName: sortedVMNames.first,
                                existingServices: dashboardViewModel.multipassServices
                            )
                            let draft = multipassViewModel.commitAssistant(existingServices: dashboardViewModel.multipassServices)
                            openEditor(sourceService: draft, existingService: nil, isDiscoveredSource: false)
                        } label: {
                            Label("Vorschlag konfigurieren", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(multipassViewModel.assistant.vmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Text(multipassViewModel.assistant.assistantHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Multipass VMs") {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedVMNames.isEmpty {
                        Text("Keine Multipass VMs erkannt.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedVMNames, id: \.self) { vmName in
                                multipassVMCard(
                                    vmName: vmName,
                                    target: targetByName[vmName],
                                    discoveredServices: discoveredByVM[vmName] ?? [],
                                    configuredServices: configuredByVM[vmName] ?? [],
                                    statusesByID: statusesByID
                                )
                            }
                        }
                    }

                    if !unassignedConfigured.isEmpty {
                        GroupBox("Manuelle Services ohne VM") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diese Services haben keinen VM-Namen. Bitte im Dialog vervollständigen.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                configuredServicesList(unassignedConfigured, statusesByID: statusesByID)
                            }
                            .padding(.top, 4)
                        }
                    }

                    if !unassignedDiscovered.isEmpty {
                        GroupBox("Entdeckte YAML-Services ohne VM") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diese YAML-Services konnten keiner VM zugeordnet werden.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                discoveredServicesList(unassignedDiscovered)
                            }
                            .padding(.top, 4)
                        }
                    }

                    if let result = dashboardViewModel.lastMultipassVMControlResult {
                        StatusMessageView(message: result.message, isSuccess: result.succeeded)
                    }

                    if let result = dashboardViewModel.lastMultipassServiceControlResult {
                        StatusMessageView(message: result.message, isSuccess: result.succeeded)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func multipassVMCard(
        vmName: String,
        target: RuntimeTarget?,
        discoveredServices: [MultipassServiceDraft],
        configuredServices: [MultipassServiceDraft],
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
                    if let host = multipassViewModel.autoHost(for: vmName) {
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
                        dashboardViewModel.controlMultipassVM(vmName: vmName, action: .start)
                    } label: {
                        Label("Start", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(dashboardViewModel.isChangingMultipassVMRuntime || dashboardViewModel.isChangingMultipassServiceRuntime)
                }

                if canStop {
                    Button {
                        dashboardViewModel.controlMultipassVM(vmName: vmName, action: .stop)
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(dashboardViewModel.isChangingMultipassVMRuntime || dashboardViewModel.isChangingMultipassServiceRuntime)

                    Button(role: .destructive) {
                        dashboardViewModel.controlMultipassVM(vmName: vmName, action: .forceStop)
                    } label: {
                        Label("Force-Stop", systemImage: "exclamationmark.octagon.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(dashboardViewModel.isChangingMultipassVMRuntime || dashboardViewModel.isChangingMultipassServiceRuntime)
                }

                Spacer()

                Button {
                    openEditor(
                        sourceService: MultipassServiceDraft.defaultForVM(vmName, existingServices: dashboardViewModel.multipassServices),
                        existingService: nil,
                        isDiscoveredSource: false
                    )
                } label: {
                    Label("Service hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Manuell konfiguriert")
                    .font(.subheadline.weight(.semibold))
                if configuredServices.isEmpty {
                    Text("Noch keine manuell gespeicherten Services für diese VM.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    configuredServicesList(configuredServices, statusesByID: statusesByID)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Per YAML entdeckt")
                    .font(.subheadline.weight(.semibold))
                if discoveredServices.isEmpty {
                    Text("Keine Services aus `/etc/caddy-app.yaml` erkannt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    discoveredServicesList(discoveredServices)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func configuredServicesList(
        _ services: [MultipassServiceDraft],
        statusesByID: [UUID: MultipassServiceRuntimeStatus]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(services.sorted {
                $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
            }, id: \.id) { service in
                let runtimeStatus = statusesByID[service.id]
                serviceListRow(
                    service: service,
                    badgeText: "Manuell",
                    badgeColor: .blue,
                    statusText: statusSummary(for: runtimeStatus)
                ) {
                    openEditor(sourceService: service, existingService: service, isDiscoveredSource: false)
                } actions: {
                    configuredServiceActions(for: service)
                }
            }
        }
    }

    private func discoveredServicesList(_ services: [MultipassServiceDraft]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(services.sorted {
                $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
            }, id: \.configurationKey) { service in
                let existingService = dashboardViewModel.multipassServices.first(where: { $0.configurationKey == service.configurationKey })
                serviceListRow(
                    service: service,
                    badgeText: existingService == nil ? nil : "Konfiguriert",
                    badgeColor: .green,
                    statusText: nil
                ) {
                    openEditor(sourceService: service, existingService: existingService, isDiscoveredSource: true)
                } actions: {
                    EmptyView()
                }
            }
        }
    }

    private func serviceListRow<Actions: View>(
        service: MultipassServiceDraft,
        badgeText: String?,
        badgeColor: Color,
        statusText: String?,
        openEditorAction: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(service.serviceName)
                            .font(.subheadline.weight(.semibold))
                        if let badgeText {
                            Text(badgeText)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badgeColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(service.scheme.rawValue) • \(service.targetPort) • \(service.host)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if let statusText, !statusText.isEmpty {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Button("Details") {
                    openEditorAction()
                }
                .buttonStyle(.bordered)
            }

            actions()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func configuredServiceActions(for service: MultipassServiceDraft) -> some View {
        let hasSystemdUnit = !service.systemdUnit.isEmpty
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                configuredServiceActionButtons(service: service, hasSystemdUnit: hasSystemdUnit)
            }
            VStack(alignment: .leading, spacing: 8) {
                configuredServiceActionButtons(service: service, hasSystemdUnit: hasSystemdUnit)
            }
        }
    }

    @ViewBuilder
    private func configuredServiceActionButtons(service: MultipassServiceDraft, hasSystemdUnit: Bool) -> some View {
        Button {
            dashboardViewModel.controlMultipassService(serviceID: service.id, action: .start)
        } label: {
            Label("Start", systemImage: "play.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

        Button {
            dashboardViewModel.controlMultipassService(serviceID: service.id, action: .stop)
        } label: {
            Label("Stop", systemImage: "stop.circle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

        if hasSystemdUnit {
            Button {
                dashboardViewModel.controlMultipassService(serviceID: service.id, action: .startSystemd)
            } label: {
                Label("Start unit", systemImage: "bolt.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

            Button {
                dashboardViewModel.controlMultipassService(serviceID: service.id, action: .restartSystemd)
            } label: {
                Label("Restart unit", systemImage: "arrow.clockwise.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

            Button {
                dashboardViewModel.controlMultipassService(serviceID: service.id, action: .stopSystemd)
            } label: {
                Label("Stop unit", systemImage: "power.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)
        }

        Button(role: .destructive) {
            dashboardViewModel.removeMultipassService(id: service.id)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
    }

    private func assistantRow(vmNames: [String]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Picker("VM", selection: $multipassViewModel.assistant.vmName) {
                    Text("VM wählen").tag("")
                    ForEach(vmNames, id: \.self) { vmName in
                        Text(vmName).tag(vmName)
                    }
                }
                .frame(maxWidth: 220)

                TextField("Service", text: $multipassViewModel.assistant.serviceName)
                    .textFieldStyle(.roundedBorder)
                TextField("Port", value: $multipassViewModel.assistant.targetPort, formatter: multipassViewModel.integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Picker("Scheme", selection: $multipassViewModel.assistant.scheme) {
                    Text("http").tag(MultipassServiceScheme.http)
                    Text("https").tag(MultipassServiceScheme.https)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                Text(multipassViewModel.assistant.suggestedHost)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Picker("VM", selection: $multipassViewModel.assistant.vmName) {
                    Text("VM wählen").tag("")
                    ForEach(vmNames, id: \.self) { vmName in
                        Text(vmName).tag(vmName)
                    }
                }
                TextField("Service", text: $multipassViewModel.assistant.serviceName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Port", value: $multipassViewModel.assistant.targetPort, formatter: multipassViewModel.integerFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Picker("Scheme", selection: $multipassViewModel.assistant.scheme) {
                        Text("http").tag(MultipassServiceScheme.http)
                        Text("https").tag(MultipassServiceScheme.https)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                Text(multipassViewModel.assistant.suggestedHost)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func serviceVMGroupKey(_ service: MultipassServiceDraft) -> String {
        let name = service.vmName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unzugeordnet" : name
    }

    private func statusSummary(for runtimeStatus: MultipassServiceRuntimeStatus?) -> String? {
        guard let runtimeStatus else { return nil }
        return "VM: \(runtimeStatus.vmStatus) • systemd: \(runtimeStatus.systemdStatus) • phase: \(runtimeStatus.phase.label)"
    }

    private func openEditor(
        sourceService: MultipassServiceDraft,
        existingService: MultipassServiceDraft?,
        isDiscoveredSource: Bool
    ) {
        serviceEditorContext = ServiceEditorContext(
            sourceService: sourceService,
            existingService: existingService,
            isDiscoveredSource: isDiscoveredSource
        )
    }
}
