import Foundation

enum OnDemandAppPhase: String, Codable {
    case stopped
    case starting
    case running
    case stopping
    case error

    var label: String { rawValue.capitalized }
}
