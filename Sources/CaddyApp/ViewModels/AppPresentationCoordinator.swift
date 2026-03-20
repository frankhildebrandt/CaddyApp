import Foundation

@MainActor
final class AppPresentationCoordinator: ObservableObject {
    enum Dialog: String, Identifiable {
        case caddyUpdate
        case reloadConfig

        var id: String { rawValue }
    }

    @Published private(set) var activeDialog: Dialog?
    @Published var isOnDemandPresetPickerPresented = false

    func present(_ dialog: Dialog) {
        guard activeDialog != dialog else { return }
        activeDialog = dialog
    }

    func dismissDialog() {
        activeDialog = nil
    }
}
