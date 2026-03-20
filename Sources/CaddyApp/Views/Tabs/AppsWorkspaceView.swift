import SwiftUI

struct AppsWorkspaceView: View {
    let snapshot: DashboardSnapshot
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator
    @StateObject private var onDemandViewModel = OnDemandViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apps")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                Text("On-Demand-Apps und Presets sind jetzt als eigener Arbeitsbereich zusammengefasst.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppChrome.secondaryText)
            }

            SettingsOnDemandPaneView(
                snapshot: snapshot,
                dashboardViewModel: viewModel,
                onDemandViewModel: onDemandViewModel,
                presentationCoordinator: presentationCoordinator
            )
            .frame(minHeight: 520)
        }
        .padding(18)
    }
}
