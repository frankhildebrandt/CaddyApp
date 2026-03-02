import SwiftUI

struct OnDemandPresetPickerView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var onDemandViewModel: OnDemandViewModel
    @Binding var isPresented: Bool

    var body: some View {
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

                            ForEach(Array(dashboardViewModel.appRepositories.indices), id: \.self) { index in
                                appRepositoryRow(at: index)
                            }

                            HStack(spacing: 8) {
                                Button {
                                    dashboardViewModel.addAppRepository()
                                } label: {
                                    Label("Repository hinzufügen", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    dashboardViewModel.refreshAppRepositoryPresets()
                                } label: {
                                    Label("Web-Repositories aktualisieren", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(dashboardViewModel.isRefreshingAppRepositories)

                                if dashboardViewModel.isRefreshingAppRepositories {
                                    InlineActivitySkeleton()
                                }
                            }

                            if let result = dashboardViewModel.lastRepositorySyncResult {
                                VStack(alignment: .leading, spacing: 4) {
                                    StatusMessageView(message: result.message, isSuccess: result.succeeded)
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

                    let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

                    Text("Lokale Presets")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: columns, spacing: 12) {
                        onDemandAddOptionTile(
                            title: "Custom App",
                            iconSystemName: "slider.horizontal.3",
                            summary: "Leere On-Demand-App mit eigener Runtime/Start-Konfiguration.",
                            meta: "Podman/Docker • frei konfigurierbar"
                        ) {
                            dashboardViewModel.addOnDemandApp()
                            onDemandViewModel.selectedOnDemandAppID = nil
                            isPresented = false
                        }

                        ForEach(OnDemandAppPresetCatalog.all) { preset in
                            onDemandAddOptionTile(
                                title: preset.title,
                                iconSystemName: preset.iconSystemName,
                                summary: preset.summary,
                                meta: "\(preset.app.runtime.label) • \(preset.app.host) • Port \(preset.app.targetPort)"
                            ) {
                                dashboardViewModel.addOnDemandPreset(preset)
                                onDemandViewModel.selectedOnDemandAppID = nil
                                isPresented = false
                            }
                        }
                    }

                    if !dashboardViewModel.remoteOnDemandPresets.isEmpty {
                        Text("Repository Presets")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(dashboardViewModel.remoteOnDemandPresets) { preset in
                                onDemandAddOptionTile(
                                    title: preset.title,
                                    iconSystemName: preset.iconSystemName,
                                    summary: preset.summary,
                                    meta: "\(preset.app.runtime.label) • \(preset.app.host) • Port \(preset.app.targetPort)"
                                ) {
                                    dashboardViewModel.addOnDemandPreset(preset)
                                    onDemandViewModel.selectedOnDemandAppID = nil
                                    isPresented = false
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
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            if !dashboardViewModel.isRefreshingAppRepositories, dashboardViewModel.remoteOnDemandPresets.isEmpty {
                dashboardViewModel.refreshAppRepositoryPresets()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private func appRepositoryRow(at index: Int) -> some View {
        let repositoryBinding = $dashboardViewModel.appRepositories[index]
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
                    dashboardViewModel.moveAppRepositoryUp(id: repositoryID)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                Button {
                    dashboardViewModel.moveAppRepositoryDown(id: repositoryID)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    dashboardViewModel.removeAppRepository(id: repositoryID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func onDemandAddOptionTile(
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
