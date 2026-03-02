import Foundation

struct AppIndexDocument: Decodable {
    struct Spec: Decodable {
        struct Item: Decodable {
            var key: String?
            var url: String
        }

        var apps: [Item]
    }

    var spec: Spec
}
