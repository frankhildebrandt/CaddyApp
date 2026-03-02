import Foundation

struct OnDemandAppDocument: Decodable {
    struct Metadata: Decodable {
        var key: String
        var name: String
        var summary: String
    }

    var metadata: Metadata
    var spec: OnDemandAppDraft.RepositorySpec
}
