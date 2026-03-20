import SwiftUI

struct AppSidebarView: View {
    @Binding var selectedTab: AppSidebarTab?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                AppBrandIcon(size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CaddyApp")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppChrome.primaryText)
                    Text("Control Center")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppChrome.secondaryText)
                }
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Start")
                sidebarButton(for: .overview)
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Bereiche")
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
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppChrome.sidebarFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1)
                )
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(AppChrome.secondaryText)
            .padding(.leading, 4)
            .padding(.top, 8)
    }

    private func sidebarButton(for tab: AppSidebarTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                Text(tab.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(AppChrome.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((selectedTab ?? .overview) == tab ? AppChrome.selectionFill : Color.clear)
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
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(AppChrome.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }
}
