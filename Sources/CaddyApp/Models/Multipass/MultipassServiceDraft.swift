import Foundation

struct MultipassServiceDraft: Identifiable, Hashable, Codable {
    var id: UUID
    var vmName: String
    var serviceName: String
    var host: String
    var targetPort: Int
    var scheme: MultipassServiceScheme
    var healthPath: String
    var enabled: Bool
    var autoStartVM: Bool
    var autoStopVM: Bool
    var autoStartSystemd: Bool
    var autoStopSystemd: Bool
    var idleTimeoutSeconds: Int
    var systemdUnit: String
    var managedByYAML: Bool

    init(
        id: UUID = UUID(),
        vmName: String,
        serviceName: String,
        host: String,
        targetPort: Int,
        scheme: MultipassServiceScheme = .http,
        healthPath: String = "/",
        enabled: Bool = true,
        autoStartVM: Bool = true,
        autoStopVM: Bool = true,
        autoStartSystemd: Bool = true,
        autoStopSystemd: Bool = false,
        idleTimeoutSeconds: Int = 600,
        systemdUnit: String = "",
        managedByYAML: Bool = false
    ) {
        self.id = id
        self.vmName = vmName
        self.serviceName = serviceName
        self.host = host
        self.targetPort = targetPort
        self.scheme = scheme
        self.healthPath = healthPath
        self.enabled = enabled
        self.autoStartVM = autoStartVM
        self.autoStopVM = autoStopVM
        self.autoStartSystemd = autoStartSystemd
        self.autoStopSystemd = autoStopSystemd
        self.idleTimeoutSeconds = idleTimeoutSeconds
        self.systemdUnit = systemdUnit
        self.managedByYAML = managedByYAML
    }

    func asProxyRoute(gatewayPort: UInt16) -> ProxyRoute {
        ProxyRoute(
            host: host,
            upstream: "127.0.0.1:\(gatewayPort)",
            source: .multipassService,
            enabled: enabled
        )
    }

    func normalized() -> MultipassServiceDraft {
        var normalized = self
        normalized.vmName = vmName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.serviceName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.healthPath = healthPath.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.systemdUnit = systemdUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }

    static func defaultForVM(_ vmName: String, existingServices: [MultipassServiceDraft]) -> MultipassServiceDraft {
        let normalizedVMName = vmName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedVMName.isEmpty else {
            return MultipassServiceDraft(vmName: "", serviceName: "", host: "", targetPort: 8080)
        }

        let vmLabel = DNSLabel.normalize(normalizedVMName) ?? "vm"
        let existingNames = Set(
            existingServices
                .filter { $0.vmName.caseInsensitiveCompare(normalizedVMName) == .orderedSame }
                .map { $0.serviceName.lowercased() }
        )

        var serviceName = "service"
        var suffix = 1
        while existingNames.contains(serviceName.lowercased()) {
            suffix += 1
            serviceName = "service\(suffix)"
        }

        return MultipassServiceDraft(
            vmName: normalizedVMName,
            serviceName: serviceName,
            host: "\(serviceName).\(vmLabel).mp.localhost",
            targetPort: 8080
        )
    }
}
