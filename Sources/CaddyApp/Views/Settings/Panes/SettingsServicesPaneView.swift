import SwiftUI

struct SettingsServicesPaneView: View {
    let snapshot: DashboardSnapshot?
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var multipassViewModel: MultipassViewModel
    @State private var selectedDiscoveredService: MultipassServiceDraft?

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
        .sheet(item: $selectedDiscoveredService) { service in
            MultipassDiscoveredServiceDetailView(
                sourceService: service,
                existingService: dashboardViewModel.multipassServices.first(where: { $0.configurationKey == service.configurationKey }),
                dashboardViewModel: dashboardViewModel,
                multipassViewModel: multipassViewModel
            )
        }
    }

    private func multipassSection(_ snapshot: DashboardSnapshot) -> some View {
        let multipassTargets = snapshot.runtimeTargets.filter { $0.source == .multipass }
        let targetByName = Dictionary(uniqueKeysWithValues: multipassTargets.map { ($0.name, $0) })
        let statusesByID = Dictionary(uniqueKeysWithValues: snapshot.multipassServiceStatuses.map { ($0.id, $0) })
        let discoveredByVM = Dictionary(grouping: snapshot.discoveredMultipassServices, by: { service in
            let name = service.vmName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Unzugeordnet" : name
        })
        let servicesByVM = Dictionary(grouping: Array(dashboardViewModel.multipassServices.indices), by: { index in
            let name = dashboardViewModel.multipassServices[index].vmName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Unzugeordnet" : name
        })
        var vmNames = Set(multipassTargets.map(\.name))
        vmNames.formUnion(servicesByVM.keys.filter { $0 != "Unzugeordnet" })
        vmNames.formUnion(discoveredByVM.keys.filter { $0 != "Unzugeordnet" })
        let sortedVMNames = vmNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let unassignedServiceIndices = servicesByVM["Unzugeordnet"] ?? []
        let unassignedDiscoveredServices = discoveredByVM["Unzugeordnet"] ?? []

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
                            dashboardViewModel.addMultipassService(draft)
                        } label: {
                            Label("Vorschlag übernehmen", systemImage: "wand.and.stars")
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

                    if !unassignedDiscoveredServices.isEmpty {
                        GroupBox("Entdeckte YAML-Services ohne VM") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Diese YAML-Services konnten keiner VM zugeordnet werden.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                discoveredServicesList(unassignedDiscoveredServices)
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
                    dashboardViewModel.addMultipassService(forVMName: vmName)
                } label: {
                    Label("Service hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
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

    private func discoveredServicesList(_ services: [MultipassServiceDraft]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(services.sorted {
                $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
            }, id: \.configurationKey) { service in
                let existingService = dashboardViewModel.multipassServices.first(where: { $0.configurationKey == service.configurationKey })
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(service.serviceName)
                                .font(.subheadline.weight(.semibold))
                            if existingService != nil {
                                Text("Konfiguriert")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(service.scheme.rawValue) • \(service.targetPort) • \(service.host)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(existingService == nil ? "Konfigurieren" : "Details") {
                        selectedDiscoveredService = service
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func multipassServiceRow(
        at index: Int,
        vmName: String?,
        statusesByID: [UUID: MultipassServiceRuntimeStatus]
    ) -> some View {
        let serviceBinding = $dashboardViewModel.multipassServices[index]
        let serviceID = serviceBinding.wrappedValue.id
        let runtimeStatus = statusesByID[serviceID]

        return VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                primaryServiceRowCompact(serviceBinding: serviceBinding, vmName: vmName)
                primaryServiceRowStacked(serviceBinding: serviceBinding, vmName: vmName)
            }

            ViewThatFits(in: .horizontal) {
                secondaryServiceRowCompact(serviceBinding: serviceBinding)
                secondaryServiceRowStacked(serviceBinding: serviceBinding)
            }

            ViewThatFits(in: .horizontal) {
                tertiaryServiceRowCompact(serviceBinding: serviceBinding)
                tertiaryServiceRowStacked(serviceBinding: serviceBinding)
            }

            if let runtimeStatus {
                Text("VM: \(runtimeStatus.vmStatus) • systemd: \(runtimeStatus.systemdStatus) • phase: \(runtimeStatus.phase.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionsRow(for: serviceID, hasSystemdUnit: !serviceBinding.wrappedValue.systemdUnit.isEmpty)
            Divider()
        }
    }

    @ViewBuilder
    private func actionsRow(for serviceID: UUID, hasSystemdUnit: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                serviceActionButtons(serviceID: serviceID, hasSystemdUnit: hasSystemdUnit)
            }
            VStack(alignment: .leading, spacing: 8) {
                serviceActionButtons(serviceID: serviceID, hasSystemdUnit: hasSystemdUnit)
            }
        }
    }

    @ViewBuilder
    private func serviceActionButtons(serviceID: UUID, hasSystemdUnit: Bool) -> some View {
        Button {
            dashboardViewModel.controlMultipassService(serviceID: serviceID, action: .start)
        } label: {
            Label("Start", systemImage: "play.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

        Button {
            dashboardViewModel.controlMultipassService(serviceID: serviceID, action: .stop)
        } label: {
            Label("Stop", systemImage: "stop.circle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

        if hasSystemdUnit {
            Button {
                dashboardViewModel.controlMultipassService(serviceID: serviceID, action: .startSystemd)
            } label: {
                Label("Start unit", systemImage: "bolt.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

            Button {
                dashboardViewModel.controlMultipassService(serviceID: serviceID, action: .restartSystemd)
            } label: {
                Label("Restart unit", systemImage: "arrow.clockwise.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)

            Button {
                dashboardViewModel.controlMultipassService(serviceID: serviceID, action: .stopSystemd)
            } label: {
                Label("Stop unit", systemImage: "power.circle")
            }
            .buttonStyle(.bordered)
            .disabled(dashboardViewModel.isChangingMultipassServiceRuntime)
        }

        Button(role: .destructive) {
            dashboardViewModel.removeMultipassService(id: serviceID)
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

    private func primaryServiceRowCompact(
        serviceBinding: Binding<MultipassServiceDraft>,
        vmName: String?
    ) -> some View {
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
    }

    private func primaryServiceRowStacked(
        serviceBinding: Binding<MultipassServiceDraft>,
        vmName: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }
            TextField("Service", text: serviceBinding.serviceName)
                .textFieldStyle(.roundedBorder)
            TextField("Host", text: serviceBinding.host)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func secondaryServiceRowCompact(
        serviceBinding: Binding<MultipassServiceDraft>
    ) -> some View {
        HStack {
            TextField("Port", value: serviceBinding.targetPort, formatter: multipassViewModel.integerFormatter)
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
            TextField("Idle s", value: serviceBinding.idleTimeoutSeconds, formatter: multipassViewModel.integerFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
        }
    }

    private func secondaryServiceRowStacked(
        serviceBinding: Binding<MultipassServiceDraft>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Port", value: serviceBinding.targetPort, formatter: multipassViewModel.integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Picker("Scheme", selection: serviceBinding.scheme) {
                    Text("http").tag(MultipassServiceScheme.http)
                    Text("https").tag(MultipassServiceScheme.https)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                TextField("Idle s", value: serviceBinding.idleTimeoutSeconds, formatter: multipassViewModel.integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }
            HStack {
                Toggle("AutoStart VM", isOn: serviceBinding.autoStartVM)
                    .toggleStyle(.checkbox)
                Toggle("AutoStop VM", isOn: serviceBinding.autoStopVM)
                    .toggleStyle(.checkbox)
            }
        }
    }

    private func tertiaryServiceRowCompact(
        serviceBinding: Binding<MultipassServiceDraft>
    ) -> some View {
        HStack {
            TextField("systemd unit (optional)", text: serviceBinding.systemdUnit)
                .textFieldStyle(.roundedBorder)
            Toggle("AutoStart systemd", isOn: serviceBinding.autoStartSystemd)
                .toggleStyle(.checkbox)
            Toggle("AutoStop systemd", isOn: serviceBinding.autoStopSystemd)
                .toggleStyle(.checkbox)
        }
    }

    private func tertiaryServiceRowStacked(
        serviceBinding: Binding<MultipassServiceDraft>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("systemd unit (optional)", text: serviceBinding.systemdUnit)
                .textFieldStyle(.roundedBorder)
            HStack {
                Toggle("AutoStart systemd", isOn: serviceBinding.autoStartSystemd)
                    .toggleStyle(.checkbox)
                Toggle("AutoStop systemd", isOn: serviceBinding.autoStopSystemd)
                    .toggleStyle(.checkbox)
            }
        }
    }
}
