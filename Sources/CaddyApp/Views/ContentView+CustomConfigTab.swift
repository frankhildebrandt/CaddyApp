import SwiftUI

extension ContentView {
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
}
