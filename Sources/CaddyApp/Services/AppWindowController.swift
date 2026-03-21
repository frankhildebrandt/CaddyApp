import AppKit

struct AppWindowController {
    static let mainWindowID = "main-window"
    static let documentationWindowID = "documentation-window"
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
    private var localKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let activeModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard event.keyCode == 122, activeModifiers.isEmpty else {
                return event
            }

            AppWindowRouter.shared.openDocumentationWindow()
            return nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }
}
