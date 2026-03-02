import SwiftUI

struct OnDemandDetailView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var onDemandViewModel: OnDemandViewModel
    @Binding var app: OnDemandAppDraft
    let runtimeStatus: OnDemandAppRuntimeStatus?

    var body: some View {
        let appID = app.id
        let phase = runtimeStatus?.phase ?? .stopped
        let isEnabled = app.enabled

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name.isEmpty ? "Neue App" : app.name)
                            .font(.headline)
                        Text(app.runtime.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(app.unitKind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("https://\(app.host.isEmpty ? "host.localhost" : app.host)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("\(app.targetHost):\(app.targetPort) • idle \(app.idleTimeoutSeconds)s • gateway \(OnDemandAppsService.gatewayPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastAccessAt = runtimeStatus?.lastAccessAt {
                        Text("Letzter Zugriff: \(lastAccessAt.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let lastError = runtimeStatus?.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(isEnabled ? phase.label : "Disabled")
                        .foregroundStyle(isEnabled ? onDemandViewModel.onDemandPhaseColor(phase) : .secondary)

                    HStack(spacing: 6) {
                        if isEnabled {
                            Button {
                                dashboardViewModel.setOnDemandAppRunning(appID: appID, shouldRun: phase != .running)
                            } label: {
                                Image(systemName: phase == .running ? "stop.fill" : "play.fill")
                                    .frame(width: 14, height: 14)
                            }
                            .help(phase == .running ? "Stop" : "Start")
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(dashboardViewModel.isChangingOnDemandAppRuntime)
                        }

                        Button("Löschen", role: .destructive) {
                            onDemandViewModel.removeOnDemandAppAndUpdateSelection(viewModel: dashboardViewModel, id: appID)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Picker("Sub-Tab", selection: $onDemandViewModel.selectedOnDemandSubTab) {
                ForEach(OnDemandSubTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: onDemandViewModel.selectedOnDemandSubTab) { oldTab, newTab in
                if oldTab == .shell, newTab != .shell {
                    onDemandViewModel.onDemandShellSession.stop()
                }
                onDemandViewModel.loadOnDemandSubTab(tab: newTab, app: app, viewModel: dashboardViewModel)
            }

            switch onDemandViewModel.selectedOnDemandSubTab {
            case .config:
                OnDemandEditorView(app: $app) {
                    onDemandViewModel.removeOnDemandAppAndUpdateSelection(viewModel: dashboardViewModel, id: app.id)
                }
            case .hostLog:
                OnDemandLogsView(
                    kind: .host,
                    app: app,
                    text: onDemandViewModel.onDemandHostLogByAppID[app.id] ?? "",
                    isLoading: false
                ) {
                    onDemandViewModel.onDemandHostLogByAppID[app.id] = dashboardViewModel.hostLogText(for: app)
                }
            case .containerLog:
                OnDemandLogsView(
                    kind: .container,
                    app: app,
                    text: onDemandViewModel.onDemandContainerLogByAppID[app.id] ?? "",
                    isLoading: onDemandViewModel.onDemandLoadingByAppID[app.id] == true
                ) {
                    onDemandViewModel.refreshOnDemandContainerLog(app: app, viewModel: dashboardViewModel)
                }
            case .shell:
                OnDemandShellView(
                    shellSession: onDemandViewModel.onDemandShellSession,
                    shellInput: $onDemandViewModel.onDemandShellInput,
                    app: app
                )
            case .eventLog:
                OnDemandLogsView(
                    kind: .event,
                    app: app,
                    text: onDemandViewModel.onDemandEventLogByAppID[app.id] ?? "",
                    isLoading: false
                ) {
                    onDemandViewModel.onDemandEventLogByAppID[app.id] = dashboardViewModel.eventLogText(for: app)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
