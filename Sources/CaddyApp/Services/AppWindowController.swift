import AppKit

struct AppWindowController {
    static let mainWindowID = "main-window"
    static let hideOnClosePreferenceKey = "hideWindowToMenuBarOnClose"

    @MainActor
    func hideAppToMenuBar() {
        NSApp.hide(nil)
    }
}

@MainActor
final class MainWindowCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowCloseDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let shouldHideOnClose = UserDefaults.standard.bool(forKey: AppWindowController.hideOnClosePreferenceKey)
        guard shouldHideOnClose else {
            return true
        }

        NSApp.hide(nil)
        return false
    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
