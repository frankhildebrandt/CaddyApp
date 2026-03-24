import SwiftUI

struct AppSidebarView: View {
    @Binding var selectedTab: AppSidebarTab?
    let onOpenSupport: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Workspace")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)
                Text("Navigation, Support und App-Steuerung in einer ruhigen Liquid-Sidebar.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppChrome.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)

            List(selection: $selectedTab) {
                Section("Start") {
                    sidebarItem(for: .overview)
                }

                Section("Bereiche") {
                    ForEach([AppSidebarTab.setupStatus, .routing, .services, .apps, .monitoring], id: \.self) { tab in
                        sidebarItem(for: tab)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
            .background(.clear)

            Spacer()

            VStack(spacing: 10) {
                footerButton(title: "Support", systemImage: "questionmark.circle", action: onOpenSupport)
                footerButton(title: "Einstellungen", systemImage: "gearshape", action: onOpenSettings)
            }
            .padding(.horizontal, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appGlassCard(cornerRadius: 30, fill: AppChrome.sidebarFill, prominent: true)
    }

    private func sidebarItem(for tab: AppSidebarTab) -> some View {
        NavigationLink(value: tab) {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)
                .padding(.leading, 6)
        }
        .listRowBackground(Color.white.opacity(0.14))
        .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 8))
    }

    private func footerButton(title: String, systemImage: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(AppChrome.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .appGlassCard(cornerRadius: 16, fill: AppChrome.tileSoftFill)
        }
        .buttonStyle(.plain)
    }
}
