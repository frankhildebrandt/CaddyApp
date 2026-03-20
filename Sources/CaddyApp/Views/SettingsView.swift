import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var presentationCoordinator: AppPresentationCoordinator

    var body: some View {
        SettingsRootView(
            dashboardViewModel: viewModel,
            presentationCoordinator: presentationCoordinator
        )
        .frame(minWidth: 980, minHeight: 700)
    }
}
