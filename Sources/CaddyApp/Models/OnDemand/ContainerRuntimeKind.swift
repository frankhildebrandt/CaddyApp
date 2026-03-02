import Foundation

enum ContainerRuntimeKind: String, Codable, CaseIterable, Hashable {
    case podman
    case docker

    var label: String { rawValue.capitalized }
}
