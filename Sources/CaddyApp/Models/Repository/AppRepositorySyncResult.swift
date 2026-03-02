import Foundation

struct AppRepositorySyncResult {
    var succeeded: Bool
    var message: String
    var warnings: [String]
    var loadedPresetCount: Int
    var loadedRepositoryCount: Int
    var performedAt: Date
}
