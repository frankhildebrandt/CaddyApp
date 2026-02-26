import Foundation

enum AppPaths {
    static let appSupportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CaddyApp", isDirectory: true)

    static let managedBinDirectory = appSupportDirectory
        .appendingPathComponent("bin", isDirectory: true)

    static let managedCaddyBinary = managedBinDirectory
        .appendingPathComponent("caddy", isDirectory: false)
}
