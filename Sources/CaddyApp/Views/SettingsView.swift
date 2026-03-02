import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var hideWindowToMenuBarOnClose: Bool

    var body: some View {
        ContentView(viewModel: viewModel)
            .settingsConfigurationContent
            .frame(minWidth: 1050, minHeight: 760)
    }
}
