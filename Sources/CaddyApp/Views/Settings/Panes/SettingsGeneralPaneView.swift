import SwiftUI

struct SettingsGeneralPaneView: View {
    @ObservedObject var dashboardViewModel: DashboardViewModel

    var body: some View {
        List {
            Section("App-Verhalten") {
                Toggle("Fenster beim Schließen in die Menüleiste legen", isOn: $dashboardViewModel.hideWindowToMenuBarOnClose)
                Text("Das Hauptfenster bleibt im Hintergrund verfügbar und wird nicht beendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Arbeitsweise") {
                Text("Die eigentliche Konfiguration liegt in den AppConfig-Bereichen Feed Sync, Routing, Apps und Services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.automatic)
    }
}
