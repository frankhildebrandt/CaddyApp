import Foundation

struct CaddyUpdateOperationResult {
    var succeeded: Bool
    var message: String
    var output: String
    var previousVersion: String?
    var currentVersion: String?
    var recoveryAttempted: Bool
    var recoverySucceeded: Bool?
    var performedAt: Date
}
