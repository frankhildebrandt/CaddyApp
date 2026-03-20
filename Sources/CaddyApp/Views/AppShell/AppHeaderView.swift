import SwiftUI

struct AppHeaderView: View {
    @State private var searchQuery = ""

    let isLoading: Bool
    let runtimeStatusText: String
    let syncStatusText: String
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            compactPill(title: "Runtime", value: runtimeStatusText, systemImage: "bolt.shield")
            compactPill(title: "Feed", value: syncStatusText, systemImage: "arrow.clockwise")

            searchField

            iconButton(systemImage: "slider.horizontal.3", action: onOpenSettings)

            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isLoading ? "Lädt..." : "Aktualisieren")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppChrome.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 12) 
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppChrome.secondaryText)
            TextField("Suchen", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 14)
        .frame(width: 280, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private func compactPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppChrome.accent)
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AppChrome.secondaryText)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 72, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.88), lineWidth: 1)
        )
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppChrome.primaryText)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.88), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
