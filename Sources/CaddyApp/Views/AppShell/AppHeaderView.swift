import SwiftUI

struct AppHeaderView: View {
    @Binding var hideWindowToMenuBarOnClose: Bool
    let isLoading: Bool
    let onHideToMenuBar: () -> Void
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 12) {
                AppBrandIcon(size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("CaddyApp")
                        .font(.title.bold())
                    Text("Lokales Caddy Control Center")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onHideToMenuBar) {
                Label("Menüleiste", systemImage: "menubar.dock.rectangle")
            }
            .buttonStyle(.bordered)

            Button(action: onOpenSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Toggle("Schließen versteckt", isOn: $hideWindowToMenuBarOnClose)
                .toggleStyle(.checkbox)

            Button(action: onRefresh) {
                Label(isLoading ? "Lädt..." : "Aktualisieren", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}
