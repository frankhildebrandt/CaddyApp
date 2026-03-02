import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedPane: SettingsPane? = .general
    @Published var showOnDemandPresetPicker = false
}
