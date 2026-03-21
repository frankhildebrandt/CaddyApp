import Foundation

struct OnDemandAppRuntimeStatus: Identifiable, Hashable {
    var id: UUID
    var appID: UUID
    var name: String
    var host: String
    var runtime: ContainerRuntimeKind
    var unitKind: ContainerUnitKind
    var phase: OnDemandAppPhase
    var enabled: Bool
    var idleTimeoutSeconds: Int
    var lastAccessAt: Date?
    var lastActionAt: Date?
    var lastError: String?
    var coldStartCount: Int
    var lastWarmupDurationMs: Int?
}
