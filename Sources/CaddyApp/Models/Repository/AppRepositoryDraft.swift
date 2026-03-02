import Foundation

struct AppRepositoryDraft: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var entryURL: String
    var enabled: Bool

    init(id: UUID = UUID(), name: String, entryURL: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.entryURL = entryURL
        self.enabled = enabled
    }

    static let defaultList: [AppRepositoryDraft] = [
        AppRepositoryDraft(
            name: "CaddyApp GitHub Pages",
            entryURL: "https://frankhildebrandt.github.io/CaddyApp/repository/repositories.yaml",
            enabled: true
        )
    ]

    func normalized() -> AppRepositoryDraft {
        var normalized = self
        normalized.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.entryURL = entryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }
}
