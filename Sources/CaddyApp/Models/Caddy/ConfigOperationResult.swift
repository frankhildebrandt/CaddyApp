import Foundation

struct ConfigOperationResult {
    var kind: ConfigOperationKind
    var succeeded: Bool
    var message: String
    var output: String
    var performedAt: Date
}
