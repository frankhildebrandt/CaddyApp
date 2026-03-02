import SwiftUI

struct SettingsGeneralPaneView: View {
    @Binding var hideWindowToMenuBarOnClose: Bool

    var body: some View {
        List {
            Section("Allgemein") {
                Toggle("Schließen in Menüleiste minimieren", isOn: $hideWindowToMenuBarOnClose)
            }
        }
        .listStyle(.automatic)
    }
}
