import SwiftUI

struct SettingsCustomConfigPaneView: View {
    let snapshot: DashboardSnapshot?
    @ObservedObject var dashboardViewModel: DashboardViewModel

    var body: some View {
        List {
            if let snapshot {
                Section {
                    customConfigSection(snapshot)
                }
            } else {
                AppSkeletonView()
            }
        }
        .listStyle(.automatic)
    }

    private func customConfigSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Custom Routes") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Eigene Hosts werden mit den automatisch erkannten Runtime-Routen kombiniert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Traefik.me-Aliase fuer .localhost-Hosts aktivieren", isOn: $dashboardViewModel.enableTraefikMeAliases)
                        .toggleStyle(.checkbox)
                    Text("Erzeugt pro Host zusaetzliche Aliase wie <host>.<ip>.traefik.me (nur fuer nicht-Wildcard .localhost-Hosts).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if dashboardViewModel.customRoutes.isEmpty {
                        Text("Noch keine Custom Route angelegt.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(dashboardViewModel.customRoutes.indices), id: \.self) { index in
                                customRouteRow(at: index)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Route hinzufügen") {
                            dashboardViewModel.addCustomRoute()
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
                        TextEditor(text: $dashboardViewModel.customAdditionalCaddyfileConfig)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 160)

                        if dashboardViewModel.customAdditionalCaddyfileConfig.isEmpty {
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
                            dashboardViewModel.saveAdditionalCaddyfileConfig()
                        }
                        .disabled(dashboardViewModel.isSavingCustomConfig || dashboardViewModel.isLoading || dashboardViewModel.isChangingCaddyRuntime)

                        if dashboardViewModel.isSavingCustomConfig {
                            InlineActivitySkeleton()
                        }
                    }

                    if let validationError = dashboardViewModel.customConfigValidationError {
                        Text(validationError)
                            .foregroundStyle(.red)
                    }

                    if let saveResult = dashboardViewModel.lastCustomConfigSaveResult {
                        StatusMessageView(message: saveResult.message, isSuccess: saveResult.succeeded)
                        Text(saveResult.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let operation = dashboardViewModel.lastConfigOperation {
                        OperationResultView(
                            title: nil,
                            message: "Letzte Config-Aktion: \(operation.kind.rawValue.capitalized) - \(operation.message)",
                            detail: operation.output,
                            isSuccess: operation.succeeded
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func customRouteRow(at index: Int) -> some View {
        let routeBinding = $dashboardViewModel.customRoutes[index]
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
                dashboardViewModel.removeCustomRoute(id: routeID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Route entfernen")
        }
    }
}
