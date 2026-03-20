import SwiftUI

struct AppSidebarView: View {
    @Binding var selectedTab: AppSidebarTab?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                AppBrandIcon(size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CaddyApp")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Control Center")
                        .font(.caption)
                        .foregroundStyle(AppChrome.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Start")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppChrome.secondaryText)
                sidebarButton(for: .overview)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Bereiche")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppChrome.secondaryText)
                ForEach([AppSidebarTab.setupStatus, .routing, .services, .apps, .monitoring], id: \.self) { tab in
                    sidebarButton(for: tab)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                footerButton(title: "Support", systemImage: "questionmark.circle")
                footerButton(title: "Einstellungen", systemImage: "gearshape", action: onOpenSettings)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appGlassCard(cornerRadius: 28, fill: AppChrome.sidebarFill)
    }

    private func sidebarButton(for tab: AppSidebarTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle((selectedTab ?? .overview) == tab ? Color.white : AppChrome.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill((selectedTab ?? .overview) == tab ? AppChrome.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func footerButton(title: String, systemImage: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(AppChrome.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
        }
        .buttonStyle(.plain)
    }
}
