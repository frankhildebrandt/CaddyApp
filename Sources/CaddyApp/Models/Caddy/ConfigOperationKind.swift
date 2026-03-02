import Foundation

enum ConfigOperationKind: String {
    case write
    case validate
    case reload
    case start
    case stop
    case autoApply = "auto_apply"
}
