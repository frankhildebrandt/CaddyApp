import SwiftUI

struct AppHeaderView: View {
    let isLoading: Bool
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

            Button(action: onOpenSettings) {
                Label("AppConfig", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button(action: onRefresh) {
                Label(isLoading ? "Lädt..." : "Aktualisieren", systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
}
