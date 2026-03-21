import SwiftUI

@MainActor
final class OnDemandViewModel: ObservableObject {
    @Published var selectedOnDemandAppID: UUID?
    @Published var selectedOnDemandSubTab: OnDemandSubTab = .config
    @Published var onDemandShellInput = ""
    @Published var onDemandHostLogByAppID: [UUID: String] = [:]
    @Published var onDemandContainerLogByAppID: [UUID: String] = [:]
    @Published var onDemandEventLogByAppID: [UUID: String] = [:]
    @Published var onDemandLoadingByAppID: [UUID: Bool] = [:]

    let onDemandShellSession = OnDemandEmbeddedShellSession()

    func onDemandPhaseColor(_ phase: OnDemandAppPhase) -> Color {
        switch phase {
        case .running:
            return .green
        case .starting, .stopping:
            return .orange
        case .error:
            return .red
        case .stopped:
            return .secondary
        }
    }

    func bindingForOnDemandApp(viewModel: DashboardViewModel, id: UUID) -> Binding<OnDemandAppDraft>? {
        guard let index = viewModel.onDemandApps.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { viewModel.onDemandApps[index] },
            set: { viewModel.onDemandApps[index] = $0 }
        )
    }

    func removeOnDemandAppAndUpdateSelection(viewModel: DashboardViewModel, id: UUID) {
        viewModel.removeOnDemandApp(id: id)
        onDemandHostLogByAppID.removeValue(forKey: id)
        onDemandContainerLogByAppID.removeValue(forKey: id)
        onDemandEventLogByAppID.removeValue(forKey: id)
        onDemandLoadingByAppID.removeValue(forKey: id)
        if selectedOnDemandAppID == id {
            selectedOnDemandAppID = nil
        }
    }

    func loadOnDemandSubTab(tab: OnDemandSubTab, app: OnDemandAppDraft, viewModel: DashboardViewModel) {
        switch tab {
        case .config:
            break
        case .hostLog:
            onDemandHostLogByAppID[app.id] = viewModel.hostLogText(for: app)
        case .containerLog:
            if onDemandContainerLogByAppID[app.id] == nil {
                refreshOnDemandContainerLog(app: app, viewModel: viewModel)
            }
        case .shell:
            onDemandShellInput = ""
            onDemandShellSession.restart(for: app)
        case .eventLog:
            onDemandEventLogByAppID[app.id] = viewModel.eventLogText(for: app)
        }
    }

    func refreshOnDemandContainerLog(app: OnDemandAppDraft, viewModel: DashboardViewModel) {
        onDemandLoadingByAppID[app.id] = true
        Task {
            let text = await viewModel.fetchContainerLogText(for: app, tailLines: 200)
            onDemandContainerLogByAppID[app.id] = text
            onDemandLoadingByAppID[app.id] = false
        }
    }
}

