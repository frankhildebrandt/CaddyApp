import SwiftUI

struct OnDemandEditorView: View {
    @Binding var app: OnDemandAppDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle("Aktiv", isOn: $app.enabled)
                    .toggleStyle(.checkbox)
                TextField("Name", text: $app.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Host (z. B. grafana.localhost)", text: $app.host)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                Picker("Runtime", selection: $app.runtime) {
                    ForEach(ContainerRuntimeKind.allCases, id: \.self) { runtime in
                        Text(runtime.label).tag(runtime)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Picker("Unit", selection: $app.unitKind) {
                    ForEach(ContainerUnitKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                TextField("Container/Pod Name", text: $app.unitName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                TextField("Target Host", text: $app.targetHost)
                    .textFieldStyle(.roundedBorder)
                TextField("Target Port", value: $app.targetPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Idle (s)", value: $app.idleTimeoutSeconds, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Health Path", text: $app.healthPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }

            HStack(spacing: 8) {
                Picker("Start", selection: $app.startMode) {
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
                text: $app.runArguments
            )
            .textFieldStyle(.roundedBorder)
            .disabled(app.startMode != .runCommand)

            Text("Bei 'Run Command' wird entweder `<runtime> <runArguments>` (falls gesetzt) oder eine Preset-Run-Step-Sequenz ausgeführt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
