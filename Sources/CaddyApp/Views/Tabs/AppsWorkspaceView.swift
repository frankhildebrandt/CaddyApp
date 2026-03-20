import SwiftUI

struct AppsWorkspaceView: View {
    let snapshot: DashboardSnapshot
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator
    @StateObject private var onDemandViewModel = OnDemandViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apps")
                .font(.title2.bold())
            Text("On-Demand-Apps und Presets sind jetzt als eigener Arbeitsbereich zusammengefasst.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsOnDemandPaneView(
                snapshot: snapshot,
                dashboardViewModel: viewModel,
                onDemandViewModel: onDemandViewModel,
                presentationCoordinator: presentationCoordinator
            )
            .frame(minHeight: 520)
        }
    }
}
