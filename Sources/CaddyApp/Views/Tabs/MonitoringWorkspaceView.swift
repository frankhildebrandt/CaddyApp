import SwiftUI

struct MonitoringWorkspaceView: View {
    let snapshot: DashboardSnapshot?
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monitoring")
                .font(.title2.bold())

            if let snapshot {
                GroupBox("Runtime") {
                    RuntimeTabView(snapshot: snapshot)
                        .padding(.top, 4)
                }
            }

                GroupBox("Logs") {
                LogsTabView()
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(18)
    }
}
