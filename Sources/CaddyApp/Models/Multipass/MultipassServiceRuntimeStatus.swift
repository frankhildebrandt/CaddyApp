import Foundation

struct MultipassServiceRuntimeStatus: Identifiable, Hashable {
    var id: UUID
    var vmName: String
    var serviceName: String
    var host: String
    var targetPort: Int
    var scheme: MultipassServiceScheme
    var enabled: Bool
    var autoStartVM: Bool
    var autoStopVM: Bool
    var idleTimeoutSeconds: Int
    var systemdUnit: String
    var phase: OnDemandAppPhase
    var vmStatus: String
    var systemdStatus: String
    var lastAccessAt: Date?
    var lastActionAt: Date?
    var lastError: String?
}
