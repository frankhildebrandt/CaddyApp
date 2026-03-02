import Foundation

struct RepositoryIndexDocument: Decodable {
    struct Spec: Decodable {
        struct Repository: Decodable {
            var id: String?
            var name: String?
            var baseUrl: String?
            var indexUrl: String
            var sourceUrl: String?
            var enabled: Bool?
        }

        var repositories: [Repository]
    }

    var spec: Spec
}
