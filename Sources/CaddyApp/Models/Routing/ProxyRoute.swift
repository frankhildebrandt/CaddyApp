import Foundation

struct ProxyRoute: Identifiable, Hashable {
    let id = UUID()
    var host: String
    var upstream: String
    var source: RuntimeSource
    var enabled: Bool
    var onDemandPrepareEndpoint: String? = nil
}
