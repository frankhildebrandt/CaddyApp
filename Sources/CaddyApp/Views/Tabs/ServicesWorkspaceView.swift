import SwiftUI

struct ServicesWorkspaceView: View {
    let snapshot: DashboardSnapshot
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var multipassViewModel = MultipassViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Services")
                .font(.title2.bold())
            Text("VM-basierte Services lassen sich hier anlegen, prüfen und steuern.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsServicesPaneView(
                snapshot: snapshot,
                dashboardViewModel: viewModel,
                multipassViewModel: multipassViewModel
            )
            .frame(minHeight: 520)
        }
    }
}
