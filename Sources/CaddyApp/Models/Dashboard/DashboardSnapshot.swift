import Foundation

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
