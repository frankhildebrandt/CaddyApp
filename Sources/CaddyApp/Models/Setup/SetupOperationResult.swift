import Foundation

struct SetupOperationResult: Identifiable {
    let id = UUID()
    var kind: SetupOperationKind
    var succeeded: Bool
    var message: String
    var output: String
    var performedAt: Date
}
