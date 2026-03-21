import AppKit
import SwiftUI

enum DocumentationAccess {
    static let siteURL = URL(string: "https://frankhildebrandt.github.io/CaddyApp/")!
}

@MainActor
final class AppWindowRouter {
    static let shared = AppWindowRouter()

    private var openWindowAction: OpenWindowAction?

    func register(openWindowAction: OpenWindowAction) {
        self.openWindowAction = openWindowAction
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        openWindowAction?.callAsFunction(id: AppWindowController.mainWindowID)
    }

    func openDocumentationWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        openWindowAction?.callAsFunction(id: AppWindowController.documentationWindowID)
    }
}
