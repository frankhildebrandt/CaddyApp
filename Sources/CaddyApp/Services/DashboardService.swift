import Foundation

actor DashboardService {
    private let installService = CaddyInstallationService()
    private let configService = CaddyConfigService()
    private let customConfigStore = CustomConfigStore()
    private let tlsService = LocalhostTLSService()
    private let runtimeService = RuntimeDiscoveryService()
    private let releaseService = CaddyReleaseMonitorService()
    private let bootstrapService = EnvironmentBootstrapService()
    private let configLifecycleService = CaddyConfigLifecycleService()
    private let onDemandAppsService = OnDemandAppsService.shared

    func loadSnapshot() async -> DashboardSnapshot {
        await onDemandAppsService.startIfNeeded()
        await onDemandAppsService.reloadConfiguration()
        let runtimeTargets = runtimeService.discoverTargets()
        let customConfig = customConfigStore.load()
        let onDemandAppStatuses = await onDemandAppsService.statuses()
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: customConfig.customRoutes,
            onDemandApps: customConfig.onDemandApps,
            multipassServices: customConfig.multipassServices
        )
        var caddyInstall = installService.loadStatus()
        var tlsStatus = tlsService.status()
        let autoSetupReport = bootstrapService.runAutoSetupIfNeeded(caddyInstall: caddyInstall, tlsStatus: tlsStatus)
        if autoSetupReport.attempted {
            caddyInstall = installService.loadStatus()
            tlsStatus = tlsService.status()
        }
        let latestRelease = await releaseService.fetchLatestRelease()
        let caddyUpdateStatus = CaddyUpdateStatus(
            checked: latestRelease != nil,
            updateAvailable: installService.isUpdateAvailable(localVersion: caddyInstall.version, latestTag: latestRelease?.tagName),
            localVersion: caddyInstall.version,
            latestVersion: latestRelease?.tagName
        )
        let configPreview = configService.preview(
            for: routes,
            additionalCaddyfileConfig: customConfig.additionalCaddyfileConfig
        )
        let caddyRuntimeStatus = configLifecycleService.runtimeStatus()

        let warnings = warnings(
            caddyInstall: caddyInstall,
            tlsStatus: tlsStatus,
            runtimeTargets: runtimeTargets,
            autoSetupReport: autoSetupReport
        )

        return DashboardSnapshot(
            generatedAt: Date(),
            features: FeatureCatalog.items,
            caddyInstall: caddyInstall,
            latestRelease: latestRelease,
            caddyUpdateStatus: caddyUpdateStatus,
            caddyRuntimeStatus: caddyRuntimeStatus,
            tlsStatus: tlsStatus,
            configPreview: configPreview,
            runtimeTargets: runtimeTargets,
            onDemandAppStatuses: onDemandAppStatuses,
            multipassServiceStatuses: multipassServiceStatuses,
            routes: routes,
            warnings: warnings,
            autoSetupReport: autoSetupReport
        )
    }

    func refreshRuntimeDiscovery(on snapshot: DashboardSnapshot) async -> DashboardSnapshot {
        await onDemandAppsService.reloadConfiguration()
        let runtimeTargets = runtimeService.discoverTargets()
        let customConfig = customConfigStore.load()
        let onDemandAppStatuses = await onDemandAppsService.statuses()
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: customConfig.customRoutes,
            onDemandApps: customConfig.onDemandApps,
            multipassServices: customConfig.multipassServices
        )
        let configPreview = configService.preview(
            for: routes,
            additionalCaddyfileConfig: customConfig.additionalCaddyfileConfig
        )
        let caddyRuntimeStatus = configLifecycleService.runtimeStatus()
        let warnings = warnings(
            caddyInstall: snapshot.caddyInstall,
            tlsStatus: snapshot.tlsStatus,
            runtimeTargets: runtimeTargets,
            autoSetupReport: snapshot.autoSetupReport
        )

        return DashboardSnapshot(
            generatedAt: Date(),
            features: FeatureCatalog.items,
            caddyInstall: snapshot.caddyInstall,
            latestRelease: snapshot.latestRelease,
            caddyUpdateStatus: snapshot.caddyUpdateStatus,
            caddyRuntimeStatus: caddyRuntimeStatus,
            tlsStatus: snapshot.tlsStatus,
            configPreview: configPreview,
            runtimeTargets: runtimeTargets,
            onDemandAppStatuses: onDemandAppStatuses,
            multipassServiceStatuses: multipassServiceStatuses,
            routes: routes,
            warnings: warnings,
            autoSetupReport: snapshot.autoSetupReport
        )
    }

    private func warnings(
        caddyInstall: CaddyInstallStatus,
        tlsStatus: TLSStatus,
        runtimeTargets: [RuntimeTarget],
        autoSetupReport: AutoSetupReport
    ) -> [String] {
        var warnings: [String] = []
        if !caddyInstall.isInstalled {
            warnings.append("Caddy is not installed. The app can still prepare configuration, but cannot apply it yet.")
        }
        if !tlsStatus.rootCertificatePresent {
            warnings.append("Caddy local CA root certificate not found yet. AutoTLS for localhost subdomains will need a trust step.")
        } else if tlsStatus.systemKeychainTrustStatus == .notTrusted {
            warnings.append("Caddy local CA root certificate exists, but is not trusted in the macOS System Keychain yet.")
        }
        if runtimeTargets.isEmpty {
            warnings.append("No Multipass or Podman targets discovered.")
        }
        for operation in autoSetupReport.operations where !operation.succeeded {
            warnings.append("Auto setup failed: \(operation.message)")
        }
        return warnings
    }
}
