import Foundation

struct CaddyInstallStatus {
    var isInstalled: Bool
    var version: String?
    var binaryPath: String?
    var suggestedInstallCommand: String
}
