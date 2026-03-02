import Foundation

struct OnDemandAppDraft: Identifiable, Hashable, Codable {
    struct RepositorySpec: Decodable {
        var runtime: ContainerRuntimeKind
        var unitKind: ContainerUnitKind
        var unitName: String
        var host: String
        var targetHost: String
        var targetPort: Int
        var idleTimeoutSeconds: Int
        var enabled: Bool
        var startMode: OnDemandStartMode
        var runArguments: String?
        var runSteps: [String]?
        var healthPath: String

        var isValid: Bool {
            if unitName.isEmpty || host.isEmpty || targetHost.isEmpty {
                return false
            }
            if targetPort <= 0 || targetPort > 65535 {
                return false
            }
            if idleTimeoutSeconds < 15 {
                return false
            }
            if runtime == .docker && unitKind == .pod {
                return false
            }
            if startMode == .runCommand {
                let hasRunArguments = !(runArguments?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                let hasRunSteps = !(runSteps ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty
                if !hasRunArguments, !hasRunSteps {
                    return false
                }
            }
            return true
        }
    }

    var id: UUID
    var name: String
    var runtime: ContainerRuntimeKind
    var unitKind: ContainerUnitKind
    var unitName: String
    var host: String
    var targetHost: String
    var targetPort: Int
    var idleTimeoutSeconds: Int
    var enabled: Bool
    var startMode: OnDemandStartMode
    var runArguments: String
    var runSteps: [String]
    var healthPath: String

    init(
        id: UUID = UUID(),
        name: String,
        runtime: ContainerRuntimeKind = .podman,
        unitKind: ContainerUnitKind = .container,
        unitName: String,
        host: String,
        targetHost: String = "127.0.0.1",
        targetPort: Int,
        idleTimeoutSeconds: Int = 600,
        enabled: Bool = true,
        startMode: OnDemandStartMode = .runCommand,
        runArguments: String,
        runSteps: [String] = [],
        healthPath: String = "/"
    ) {
        self.id = id
        self.name = name
        self.runtime = runtime
        self.unitKind = unitKind
        self.unitName = unitName
        self.host = host
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.idleTimeoutSeconds = idleTimeoutSeconds
        self.enabled = enabled
        self.startMode = startMode
        self.runArguments = runArguments
        self.runSteps = runSteps
        self.healthPath = healthPath
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case runtime
        case unitKind
        case unitName
        case host
        case targetHost
        case targetPort
        case idleTimeoutSeconds
        case enabled
        case startMode
        case runArguments
        case runSteps
        case healthPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        runtime = try container.decode(ContainerRuntimeKind.self, forKey: .runtime)
        unitKind = try container.decode(ContainerUnitKind.self, forKey: .unitKind)
        unitName = try container.decode(String.self, forKey: .unitName)
        host = try container.decode(String.self, forKey: .host)
        targetHost = try container.decode(String.self, forKey: .targetHost)
        targetPort = try container.decode(Int.self, forKey: .targetPort)
        idleTimeoutSeconds = try container.decode(Int.self, forKey: .idleTimeoutSeconds)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        startMode = try container.decode(OnDemandStartMode.self, forKey: .startMode)
        runArguments = try container.decodeIfPresent(String.self, forKey: .runArguments) ?? ""
        runSteps = try container.decodeIfPresent([String].self, forKey: .runSteps) ?? []
        healthPath = try container.decodeIfPresent(String.self, forKey: .healthPath) ?? "/"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(runtime, forKey: .runtime)
        try container.encode(unitKind, forKey: .unitKind)
        try container.encode(unitName, forKey: .unitName)
        try container.encode(host, forKey: .host)
        try container.encode(targetHost, forKey: .targetHost)
        try container.encode(targetPort, forKey: .targetPort)
        try container.encode(idleTimeoutSeconds, forKey: .idleTimeoutSeconds)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(startMode, forKey: .startMode)
        try container.encode(runArguments, forKey: .runArguments)
        try container.encode(runSteps, forKey: .runSteps)
        try container.encode(healthPath, forKey: .healthPath)
    }

    func asProxyRoute(gatewayPort: UInt16) -> ProxyRoute {
        ProxyRoute(
            host: host,
            upstream: "127.0.0.1:\(gatewayPort)",
            source: .onDemand,
            enabled: enabled
        )
    }

    func normalized() -> OnDemandAppDraft {
        var normalized = self
        normalized.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.unitName = unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.targetHost = targetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.runArguments = runArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.runSteps = runSteps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        normalized.healthPath = healthPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }

    func uniquedForInsert(existingApps: [OnDemandAppDraft]) -> OnDemandAppDraft {
        var result = self
        let existingHosts = Set(existingApps.map { $0.host.lowercased() })
        if existingHosts.contains(result.host.lowercased()) {
            let baseHost = result.host.replacingOccurrences(of: ".localhost", with: "")
            var suffix = 2
            while existingHosts.contains("\(baseHost)\(suffix).localhost".lowercased()) {
                suffix += 1
            }
            result.host = "\(baseHost)\(suffix).localhost"
            result.unitName = "\(result.unitName)-\(suffix)"
            result.name = "\(result.name) \(suffix)"
        }
        return result
    }

    var hostLogNeedles: [String] {
        [
            "host=\(host.lowercased())",
            "app=\(name.lowercased())",
            host.lowercased()
        ]
    }

    var eventLogNeedles: [String] {
        [
            "app=\(name.lowercased())",
            "unit=\(unitKind.rawValue):\(unitName.lowercased())",
            unitName.lowercased(),
            host.lowercased()
        ]
    }

    static let eventActionNeedles: [String] = [
        "on-demand",
        "start",
        "stop",
        "delete",
        "backup",
        "create",
        "reload",
        "requested",
        "succeeded",
        "failed"
    ]
}
