import SwiftUI

struct DocumentationSceneBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppWindowRouter.shared.register(openWindowAction: openWindow)
            }
    }
}
