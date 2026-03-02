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
}
