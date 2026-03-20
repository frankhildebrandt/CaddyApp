import SwiftUI

struct AppSidebarView: View {
    @Binding var selectedTab: AppSidebarTab?
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            .listStyle(.sidebar)

            Spacer()

            VStack(spacing: 10) {
                footerButton(title: "Support", systemImage: "questionmark.circle")
                footerButton(title: "Einstellungen", systemImage: "gearshape", action: onOpenSettings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppChrome.sidebarFill.opacity(0.82))
    }

    private func sidebarItem(for tab: AppSidebarTab) -> some View {
        NavigationLink(value: tab) {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)
                .padding(.leading, 6)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8))
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
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
        }
        .buttonStyle(.plain)
    }
}
