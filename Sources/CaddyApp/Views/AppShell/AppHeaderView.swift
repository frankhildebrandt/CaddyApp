import SwiftUI

struct AppHeaderView: View {
    let isLoading: Bool
    let runtimeStatusText: String
    let syncStatusText: String
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Spacer(minLength: 0)

            headerActions
        }
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var headerActions: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                actionRow
            }
        } else {
            actionRow
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            compactPill(title: "Runtime", value: runtimeStatusText, systemImage: "bolt.shield")
            compactPill(title: "Feed", value: syncStatusText, systemImage: "arrow.clockwise")
            iconButton(systemImage: "slider.horizontal.3", action: onOpenSettings)
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text(isLoading ? "Lädt..." : "Aktualisieren")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppChrome.accent, AppChrome.accentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: AppChrome.accent.opacity(0.25), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func compactPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppChrome.accent)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

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
        .padding(.horizontal, 12)
        .frame(height: 42)
        .appGlassCard(cornerRadius: 16, fill: AppChrome.tileSoftFill)
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppChrome.primaryText)
                .frame(width: 42, height: 42)
                .appGlassCard(cornerRadius: 16, fill: AppChrome.tileSoftFill)
        }
        .buttonStyle(.plain)
    }
}
