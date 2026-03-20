import SwiftUI

struct AppHeaderView: View {
    @State private var searchQuery = ""

    let isLoading: Bool
    let runtimeStatusText: String
    let syncStatusText: String
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            statusPill(
                title: "Runtime",
                value: runtimeStatusText,
                systemImage: "bolt.shield"
            )

            statusPill(
                title: "Feed Sync",
                value: syncStatusText,
                systemImage: "arrow.trianglehead.2.clockwise"
            )

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.84))
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppChrome.secondaryText)
                    TextField("Suchen", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: 320, minHeight: 52)

            Button(action: onOpenSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .appGlassCard(cornerRadius: 18, fill: Color.white.opacity(0.8))

            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text(isLoading ? "Lädt..." : "Aktualisieren")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 140, minHeight: 52)
            }
            .disabled(isLoading)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppChrome.accent)
            )
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private func statusPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppChrome.accent)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppChrome.secondaryText)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .appGlassCard(cornerRadius: 20, fill: Color.white.opacity(0.82))
    }
}
