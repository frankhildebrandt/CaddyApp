import Foundation

enum RuntimeSource: String, CaseIterable {
    case manual
    case onDemand = "on_demand"
    case multipass
    case multipassService = "multipass_service"
    case podman

    var label: String {
        switch self {
        case .onDemand:
            return "On-Demand"
        case .multipassService:
            return "Multipass Service"
        default:
            return rawValue.capitalized
        }
    }
}
