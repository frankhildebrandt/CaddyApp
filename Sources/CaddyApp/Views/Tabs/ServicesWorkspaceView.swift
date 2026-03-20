import SwiftUI

struct ServicesWorkspaceView: View {
    let snapshot: DashboardSnapshot
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var multipassViewModel = MultipassViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Services")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                Text("VM-basierte Services lassen sich hier anlegen, prüfen und steuern.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppChrome.secondaryText)
            }

            SettingsServicesPaneView(
                snapshot: snapshot,
                dashboardViewModel: viewModel,
                multipassViewModel: multipassViewModel
            )
            .frame(minHeight: 520)
        }
        .padding(18)
    }
}
