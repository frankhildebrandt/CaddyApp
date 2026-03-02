import Foundation

enum OnDemandStartMode: String, Codable, CaseIterable, Hashable {
    case startExisting = "start_existing"
    case runCommand = "run_command"

    var label: String {
        switch self {
        case .startExisting: return "Start Existing"
        case .runCommand: return "Run Command"
        }
    }
}
