import SwiftUI

struct MultipassDiscoveredServiceDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceService: MultipassServiceDraft
    let existingService: MultipassServiceDraft?
    @ObservedObject var dashboardViewModel: DashboardViewModel
    @ObservedObject var multipassViewModel: MultipassViewModel

    @State private var draft: MultipassServiceDraft

    init(
        sourceService: MultipassServiceDraft,
        existingService: MultipassServiceDraft?,
        dashboardViewModel: DashboardViewModel,
        multipassViewModel: MultipassViewModel
    ) {
        self.sourceService = sourceService
        self.existingService = existingService
        self.dashboardViewModel = dashboardViewModel
        self.multipassViewModel = multipassViewModel
        _draft = State(initialValue: (existingService ?? sourceService).normalized())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Quelle") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("VM", value: sourceService.vmName)
                            LabeledContent("Service", value: sourceService.serviceName)
                            LabeledContent("Host-Vorschlag", value: sourceService.host)
                            LabeledContent("Port", value: String(sourceService.targetPort))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Routing") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Aktiv", isOn: $draft.enabled)
                            TextField("Host", text: $draft.host)
                            TextField("Port", value: $draft.targetPort, formatter: multipassViewModel.integerFormatter)
                            Picker("Scheme", selection: $draft.scheme) {
                                Text("http").tag(MultipassServiceScheme.http)
                                Text("https").tag(MultipassServiceScheme.https)
                            }
                            .pickerStyle(.segmented)
                            TextField("Health Path", text: $draft.healthPath)
                            TextField("Idle Timeout (s)", value: $draft.idleTimeoutSeconds, formatter: multipassViewModel.integerFormatter)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Runtime") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("VM automatisch starten", isOn: $draft.autoStartVM)
                            Toggle("VM automatisch stoppen", isOn: $draft.autoStopVM)
                            TextField("systemd Unit", text: $draft.systemdUnit)
                            Toggle("systemd automatisch starten", isOn: $draft.autoStartSystemd)
                            Toggle("systemd automatisch stoppen", isOn: $draft.autoStopSystemd)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
            .navigationTitle(existingService == nil ? "Service konfigurieren" : "Service bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        var saved = draft.normalized()
                        saved.vmName = sourceService.vmName
                        saved.serviceName = sourceService.serviceName
                        saved.managedByYAML = true
                        if let existingService {
                            saved.id = existingService.id
                        }
                        if dashboardViewModel.saveMultipassService(saved) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
    }
}
