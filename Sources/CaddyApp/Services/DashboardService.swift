import Foundation

actor DashboardService {
    private let installService = CaddyInstallationService()
    private let configService = CaddyConfigService()
    private let appConfigStore = AppConfigStore()
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
        let appConfig = appConfigStore.load()
        let onDemandAppStatuses = await onDemandAppsService.statuses()
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: appConfig.customRoutes,
            onDemandApps: appConfig.onDemandApps,
            multipassServices: appConfig.multipassServices
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
            additionalCaddyfileConfig: appConfig.additionalCaddyfileConfig,
            enableTraefikMeAliases: appConfig.enableTraefikMeAliases
        )
        let caddyRuntimeStatus = configLifecycleService.runtimeStatus()

        let warnings = DashboardWarningsBuilder.build(
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
        let appConfig = appConfigStore.load()
        let onDemandAppStatuses = await onDemandAppsService.statuses()
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: appConfig.customRoutes,
            onDemandApps: appConfig.onDemandApps,
            multipassServices: appConfig.multipassServices
        )
        let configPreview = configService.preview(
            for: routes,
            additionalCaddyfileConfig: appConfig.additionalCaddyfileConfig,
            enableTraefikMeAliases: appConfig.enableTraefikMeAliases
        )
        let caddyRuntimeStatus = configLifecycleService.runtimeStatus()
        let warnings = DashboardWarningsBuilder.build(
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
}
