import SwiftUI

struct AppSidebarView: View {
    @Binding var selectedTab: AppSidebarTab?

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(AppSidebarTab.allCases) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }
}
