import Foundation

enum ContainerUnitKind: String, Codable, CaseIterable, Hashable {
    case container
    case pod

    var label: String { rawValue.capitalized }
}
