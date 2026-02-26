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
    var additionalCaddyfileConfig: String

    static let `default` = CustomConfigSettings(
        customRoutes: [
            CustomRouteDraft(host: "app.localhost", upstream: "127.0.0.1:3000", enabled: true),
            CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8080", enabled: true)
        ],
        additionalCaddyfileConfig: ""
    )
}

enum RuntimeSource: String, CaseIterable {
    case manual
    case multipass
    case podman

    var label: String { rawValue.capitalized }
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
    var routes: [ProxyRoute]
    var warnings: [String]
    var autoSetupReport: AutoSetupReport
}
