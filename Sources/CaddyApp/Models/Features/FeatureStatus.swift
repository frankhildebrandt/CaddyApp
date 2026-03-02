import Foundation

enum FeatureStatus: String, CaseIterable {
    case planned
    case inProgress = "in_progress"
    case done
    case blocked

    var label: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .blocked: return "Blocked"
        }
    }
}
