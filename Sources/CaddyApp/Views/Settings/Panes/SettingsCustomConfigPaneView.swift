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
            GroupBox("Routing") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Traefik.me-Aliase für .localhost-Hosts aktivieren", isOn: $dashboardViewModel.enableTraefikMeAliases)
                        .toggleStyle(.checkbox)
                        .help("Erzeugt zusätzliche Aliase wie <host>.<ip>.traefik.me für nicht-Wildcard-.localhost-Hosts.")

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

            GroupBox("Erweiterte Caddyfile-Config") {
                VStack(alignment: .leading, spacing: 8) {
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

            GroupBox("Speicherstatus") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button("Erweiterte Config speichern") {
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
