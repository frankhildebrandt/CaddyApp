import Foundation

enum FeatureStatus: String, CaseIterable {
    case planned
    case inProgress = "in_progress"
    case done
    case blocked

    var label: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .blocked: return "Blocked"
        }
    }
}

struct FeatureItem: Identifiable {
    let id: String
    let title: String
    let status: FeatureStatus
    let summary: String
    let documentPath: String
}

struct ProxyRoute: Identifiable, Hashable {
    let id = UUID()
    var host: String
    var upstream: String
    var source: RuntimeSource
    var enabled: Bool
}

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
}

struct CustomConfigSettings: Codable {
    var customRoutes: [CustomRouteDraft]
    var onDemandApps: [OnDemandAppDraft]
    var multipassServices: [MultipassServiceDraft]
    var appRepositories: [AppRepositoryDraft]
    var enableTraefikMeAliases: Bool
    var additionalCaddyfileConfig: String

    static let `default` = CustomConfigSettings(
        customRoutes: [
            CustomRouteDraft(host: "app.localhost", upstream: "127.0.0.1:3000", enabled: true),
            CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8080", enabled: true)
        ],
        onDemandApps: [],
        multipassServices: [],
        appRepositories: AppRepositoryDraft.defaultList,
        enableTraefikMeAliases: true,
        additionalCaddyfileConfig: ""
    )

    enum CodingKeys: String, CodingKey {
        case customRoutes
        case onDemandApps
        case multipassServices
        case appRepositories
        case enableTraefikMeAliases
        case additionalCaddyfileConfig
    }

    init(
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft],
        multipassServices: [MultipassServiceDraft],
        appRepositories: [AppRepositoryDraft],
        enableTraefikMeAliases: Bool,
        additionalCaddyfileConfig: String
    ) {
        self.customRoutes = customRoutes
        self.onDemandApps = onDemandApps
        self.multipassServices = multipassServices
        self.appRepositories = appRepositories
        self.enableTraefikMeAliases = enableTraefikMeAliases
        self.additionalCaddyfileConfig = additionalCaddyfileConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customRoutes = try container.decodeIfPresent([CustomRouteDraft].self, forKey: .customRoutes)
            ?? Self.default.customRoutes
        onDemandApps = try container.decodeIfPresent([OnDemandAppDraft].self, forKey: .onDemandApps)
            ?? Self.default.onDemandApps
        multipassServices = try container.decodeIfPresent([MultipassServiceDraft].self, forKey: .multipassServices)
            ?? Self.default.multipassServices
        appRepositories = try container.decodeIfPresent([AppRepositoryDraft].self, forKey: .appRepositories)
            ?? AppRepositoryDraft.defaultList
        enableTraefikMeAliases = try container.decodeIfPresent(Bool.self, forKey: .enableTraefikMeAliases)
            ?? Self.default.enableTraefikMeAliases
        additionalCaddyfileConfig = try container.decodeIfPresent(String.self, forKey: .additionalCaddyfileConfig)
            ?? Self.default.additionalCaddyfileConfig
    }
}

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
}

enum RuntimeSource: String, CaseIterable {
    case manual
    case onDemand = "on_demand"
    case multipass
    case multipassService = "multipass_service"
    case podman

    var label: String {
        switch self {
        case .onDemand:
            return "On-Demand"
        case .multipassService:
            return "Multipass Service"
        default:
            return rawValue.capitalized
        }
    }
}

enum MultipassServiceScheme: String, Codable, CaseIterable, Hashable {
    case http
    case https
}

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
}

enum ContainerRuntimeKind: String, Codable, CaseIterable, Hashable {
    case podman
    case docker

    var label: String { rawValue.capitalized }
}

enum ContainerUnitKind: String, Codable, CaseIterable, Hashable {
    case container
    case pod

    var label: String { rawValue.capitalized }
}

enum OnDemandStartMode: String, Codable, CaseIterable, Hashable {
    case startExisting = "start_existing"
    case runCommand = "run_command"

    var label: String {
        switch self {
        case .startExisting: return "Start Existing"
        case .runCommand: return "Run Command"
        }
    }
}

struct OnDemandAppDraft: Identifiable, Hashable, Codable {
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
}

enum OnDemandAppPhase: String, Codable {
    case stopped
    case starting
    case running
    case stopping
    case error

    var label: String { rawValue.capitalized }
}

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
}

struct OnDemandAppControlResult {
    var succeeded: Bool
    var message: String
    var performedAt: Date
}

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

enum MultipassServiceControlAction {
    case start
    case stop
    case startSystemd
    case restartSystemd
    case stopSystemd
}

enum MultipassVMControlAction {
    case start
    case stop
    case forceStop
}

struct OnDemandAppPreset: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var title: String
    var iconSystemName: String
    var summary: String
    var app: OnDemandAppDraft
    var notes: String
}

struct AppRepositorySyncResult {
    var succeeded: Bool
    var message: String
    var warnings: [String]
    var loadedPresetCount: Int
    var loadedRepositoryCount: Int
    var performedAt: Date
}

enum OnDemandAppPresetCatalog {
    static let all: [OnDemandAppPreset] = [
        OnDemandAppPreset(
            key: "loki",
            title: "Loki",
            iconSystemName: "text.alignleft",
            summary: "Log aggregation backend (Grafana Loki) on port 3100.",
            app: OnDemandAppDraft(
                name: "Loki",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-loki",
                host: "loki.localhost",
                targetPort: 3100,
                idleTimeoutSeconds: 600,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-loki -p 3100:3100 grafana/loki:latest",
                healthPath: "/ready"
            ),
            notes: "Starts Loki on port 3100."
        ),
        OnDemandAppPreset(
            key: "grafana",
            title: "Grafana",
            iconSystemName: "chart.xyaxis.line",
            summary: "Grafana OSS dashboard UI on port 3000.",
            app: OnDemandAppDraft(
                name: "Grafana",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-grafana",
                host: "grafana.localhost",
                targetPort: 3000,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-grafana -p 3000:3000 grafana/grafana-oss:latest",
                healthPath: "/login"
            ),
            notes: "Grafana OSS; add volumes/env vars after inserting the preset if needed."
        ),
        OnDemandAppPreset(
            key: "kimai",
            title: "Kimai",
            iconSystemName: "clock.badge.checkmark",
            summary: "Time tracking app with bundled MariaDB pod setup.",
            app: OnDemandAppDraft(
                name: "Kimai",
                runtime: .podman,
                unitKind: .pod,
                unitName: "caddyapp-kimai",
                host: "kimai.localhost",
                targetPort: 8001,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "",
                runSteps: [
                    "pod create --name caddyapp-kimai -p 8001:8001",
                    "run -d --pod caddyapp-kimai --name caddyapp-kimai-db -e MARIADB_DATABASE=kimai -e MARIADB_USER=kimai -e MARIADB_PASSWORD=kimai -e MARIADB_ROOT_PASSWORD=kimai mariadb:11",
                    "run --rm --pod caddyapp-kimai --name caddyapp-kimai-db-wait mariadb:11 sh -lc 'until mariadb-admin ping -h 127.0.0.1 -u root -pkimai --silent; do sleep 2; done'",
                    "run -d --pod caddyapp-kimai --name caddyapp-kimai-app -e ADMINMAIL=admin@kimai.localhost -e ADMINPASS=kimaiadmin -e DATABASE_URL='mysql://kimai:kimai@127.0.0.1:3306/kimai?charset=utf8mb4&serverVersion=11.4.2-MariaDB' kimai/kimai2:apache"
                ],
                healthPath: "/"
            ),
            notes: "Podman preset creates a pod with Kimai + MariaDB and waits for DB readiness before app start. Default credentials are for local dev only; change env vars before productive use."
        ),
        OnDemandAppPreset(
            key: "ephe",
            title: "Ephe",
            iconSystemName: "doc.text.magnifyingglass",
            summary: "Builds and serves Ephe from source in a Node container on port 3000 (first start is slower).",
            app: OnDemandAppDraft(
                name: "Ephe",
                runtime: .podman,
                unitKind: .container,
                unitName: "caddyapp-ephe",
                host: "ephe.localhost",
                targetPort: 3000,
                idleTimeoutSeconds: 900,
                enabled: true,
                startMode: .runCommand,
                runArguments: "run -d --name caddyapp-ephe -p 3000:3000 node:22-alpine sh -lc \"apk add --no-cache git && npm i -g pnpm && if [ ! -d /opt/ephe ]; then git clone --depth=1 https://github.com/unvalley/ephe.git /opt/ephe; fi && cd /opt/ephe && pnpm install && pnpm run build && pnpm exec vite preview --host 0.0.0.0 --port 3000 --strictPort\"",
                healthPath: "/"
            ),
            notes: "No official container image detected. Preset builds/serves Ephe inside a Node container via git clone + pnpm (first startup can take longer)."
        ),
        OnDemandAppPreset(
            key: "penpot",
            title: "Penpot",
            iconSystemName: "pencil.and.ruler",
            summary: "Collaborative design platform with frontend/backend/exporter plus Postgres+Valkey on port 9001.",
            app: OnDemandAppDraft(
                name: "Penpot",
                runtime: .podman,
                unitKind: .pod,
                unitName: "caddyapp-penpot",
                host: "penpot.localhost",
                targetPort: 9001,
                idleTimeoutSeconds: 1800,
                enabled: true,
                startMode: .runCommand,
                runArguments: "",
                runSteps: [
                    "pod create --name caddyapp-penpot -p 9001:8080",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-postgres -e POSTGRES_INITDB_ARGS=--data-checksums -e POSTGRES_DB=penpot -e POSTGRES_USER=penpot -e POSTGRES_PASSWORD=penpot -v caddyapp-penpot-postgres:/var/lib/postgresql/data:Z postgres:15",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-valkey -e VALKEY_EXTRA_FLAGS='--maxmemory 128mb --maxmemory-policy volatile-lfu' valkey/valkey:8.1",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-backend -e PENPOT_FLAGS='disable-email-verification disable-secure-session-cookies' -e PENPOT_SECRET_KEY='caddyapp-penpot-insecure-dev-key-change-me' -e PENPOT_PUBLIC_URI='http://penpot.localhost' -e PENPOT_DATABASE_URI='postgresql://127.0.0.1/penpot' -e PENPOT_DATABASE_USERNAME=penpot -e PENPOT_DATABASE_PASSWORD=penpot -e PENPOT_REDIS_URI='redis://127.0.0.1/0' -e PENPOT_OBJECTS_STORAGE_BACKEND=fs -e PENPOT_OBJECTS_STORAGE_FS_DIRECTORY=/opt/data/assets -e PENPOT_TELEMETRY_ENABLED=true -e PENPOT_TELEMETRY_REFERER=caddyapp -v caddyapp-penpot-assets:/opt/data/assets:Z penpotapp/backend:latest",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-exporter -e PENPOT_SECRET_KEY='caddyapp-penpot-insecure-dev-key-change-me' -e PENPOT_PUBLIC_URI='http://127.0.0.1:8080' -e PENPOT_REDIS_URI='redis://127.0.0.1/0' penpotapp/exporter:latest",
                    "run -d --pod caddyapp-penpot --name caddyapp-penpot-frontend -e PENPOT_FLAGS='disable-email-verification disable-secure-session-cookies' -e PENPOT_HTTP_SERVER_MAX_BODY_SIZE=367001600 -e PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE=367001600 -v caddyapp-penpot-assets:/opt/data/assets:Z penpotapp/frontend:latest"
                ],
                healthPath: "/"
            ),
            notes: "Uses the official Penpot multi-service container stack translated from the upstream docker-compose to a single Podman pod (first startup can take longer)."
        )
    ]
}

struct RuntimeTarget: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var source: RuntimeSource
    var address: String
    var status: String
}

struct CaddyInstallStatus {
    var isInstalled: Bool
    var version: String?
    var binaryPath: String?
    var suggestedInstallCommand: String
}

struct CaddyUpdateStatus {
    var checked: Bool
    var updateAvailable: Bool
    var localVersion: String?
    var latestVersion: String?
}

struct CaddyUpdateOperationResult {
    var succeeded: Bool
    var message: String
    var output: String
    var previousVersion: String?
    var currentVersion: String?
    var recoveryAttempted: Bool
    var recoverySucceeded: Bool?
    var performedAt: Date
}

struct CaddyRuntimeStatus {
    var isRunning: Bool
    var adminEndpoint: String
}

struct CaddyReleaseInfo {
    var tagName: String
    var publishedAt: Date?
    var url: URL?
}

enum CertificateTrustStatus: String {
    case trusted
    case notTrusted = "not_trusted"
    case notChecked = "not_checked"
    case unknown

    var label: String {
        switch self {
        case .trusted: return "Trusted"
        case .notTrusted: return "Not Trusted"
        case .notChecked: return "Not Checked"
        case .unknown: return "Unknown"
        }
    }
}

struct TLSStatus {
    var localCARootPath: String
    var rootCertificatePresent: Bool
    var systemKeychainTrustStatus: CertificateTrustStatus
    var systemKeychainTrustDetails: String
    var caddyTrustCommand: String
    var installHint: String
}

struct CaddyConfigPreview {
    var caddyfilePath: String
    var generatedCaddyfile: String
    var routeCount: Int
}

enum ConfigOperationKind: String {
    case write
    case validate
    case reload
    case start
    case stop
    case autoApply = "auto_apply"
}

struct ConfigOperationResult {
    var kind: ConfigOperationKind
    var succeeded: Bool
    var message: String
    var output: String
    var performedAt: Date
}

struct CustomConfigSaveResult {
    var succeeded: Bool
    var message: String
    var performedAt: Date
}

enum SetupOperationKind: String {
    case installCaddy = "install_caddy"
    case generateLocalCA = "generate_local_ca"
    case trustLocalCA = "trust_local_ca"
}

struct SetupOperationResult: Identifiable {
    let id = UUID()
    var kind: SetupOperationKind
    var succeeded: Bool
    var message: String
    var output: String
    var performedAt: Date
}

struct AutoSetupReport {
    var attempted: Bool
    var operations: [SetupOperationResult]
}

struct DashboardSnapshot {
    var generatedAt: Date
    var features: [FeatureItem]
    var caddyInstall: CaddyInstallStatus
    var latestRelease: CaddyReleaseInfo?
    var caddyUpdateStatus: CaddyUpdateStatus
    var caddyRuntimeStatus: CaddyRuntimeStatus
    var tlsStatus: TLSStatus
    var configPreview: CaddyConfigPreview
    var runtimeTargets: [RuntimeTarget]
    var onDemandAppStatuses: [OnDemandAppRuntimeStatus]
    var multipassServiceStatuses: [MultipassServiceRuntimeStatus]
    var routes: [ProxyRoute]
    var warnings: [String]
    var autoSetupReport: AutoSetupReport
}
