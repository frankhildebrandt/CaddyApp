import Foundation

struct ShellCommandIssue: Hashable {
    var label: String
    var failureCount: Int
    var nextRetryAt: Date?
    var message: String
}
