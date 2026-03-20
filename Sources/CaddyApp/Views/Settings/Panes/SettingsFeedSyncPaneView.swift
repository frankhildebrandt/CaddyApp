import SwiftUI

struct SettingsFeedSyncPaneView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel

    var body: some View {
        List {
            Section("GitHub Pages Feed Sync") {
                Toggle("Automatische Preset-Updates aktivieren", isOn: $dashboardViewModel.repositoryAutoUpdateEnabled)

                Stepper(value: $dashboardViewModel.repositoryAutoUpdateIntervalHours, in: 1...24) {
                    Text("Sync-Intervall: alle \(dashboardViewModel.repositoryAutoUpdateIntervalHours) Stunde(n)")
                }

                HStack(spacing: 10) {
                    Button {
                        dashboardViewModel.refreshAppRepositoryPresets()
                    } label: {
                        Label("Jetzt synchronisieren", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(dashboardViewModel.isRefreshingAppRepositories)

                    if dashboardViewModel.isRefreshingAppRepositories {
                        InlineActivitySkeleton()
                    }
                }

                Text(dashboardViewModel.repositorySyncStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let result = dashboardViewModel.lastRepositorySyncResult {
                    StatusMessageView(message: result.message, isSuccess: result.succeeded)
                }
            }

            Section("Repository-Quellen") {
                ForEach(Array(dashboardViewModel.appRepositories.indices), id: \.self) { index in
                    appRepositoryRow(at: index)
                }

                Button {
                    dashboardViewModel.addAppRepository()
                } label: {
                    Label("Repository hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .listStyle(.automatic)
    }

    private func appRepositoryRow(at index: Int) -> some View {
        let repositoryBinding = $dashboardViewModel.appRepositories[index]
        let repositoryID = repositoryBinding.wrappedValue.id

        return HStack(spacing: 8) {
            Toggle("", isOn: repositoryBinding.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
            TextField("Name", text: repositoryBinding.name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            TextField("URL", text: repositoryBinding.entryURL)
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
