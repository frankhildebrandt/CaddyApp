import Foundation

struct CustomRouteDraft: Identifiable, Hashable, Codable {
    var id: UUID
    var host: String
    var upstream: String
    var enabled: Bool

    init(
        id: UUID = UUID(),
        host: String,
        upstream: String,
        enabled: Bool = true
    ) {
        self.id = id
        self.host = host
        self.upstream = upstream
        self.enabled = enabled
    }

    func asProxyRoute() -> ProxyRoute {
        ProxyRoute(host: host, upstream: upstream, source: .manual, enabled: enabled)
    }

    func normalized() -> CustomRouteDraft {
        CustomRouteDraft(
            id: id,
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            upstream: upstream.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: enabled
        )
    }
}
