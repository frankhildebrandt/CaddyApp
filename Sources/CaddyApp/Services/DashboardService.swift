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
        let discoveredMultipassServices = await onDemandAppsService.discoverMultipassServicesFromYAML()
        let effectiveMultipassServices = mergedMultipassServices(
            savedServices: appConfig.multipassServices,
            discoveredServices: discoveredMultipassServices
        )
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: appConfig.customRoutes,
            onDemandApps: appConfig.onDemandApps,
            multipassServices: effectiveMultipassServices
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
        let runtimeCommandIssues = ShellCommandBackoffStore.shared.dashboardIssues()

        let warnings = DashboardWarningsBuilder.build(
            caddyInstall: caddyInstall,
            tlsStatus: tlsStatus,
            runtimeTargets: runtimeTargets,
            autoSetupReport: autoSetupReport,
            runtimeCommandIssues: runtimeCommandIssues
        )

        return DashboardSnapshot(
            generatedAt: Date(),
            caddyInstall: caddyInstall,
            latestRelease: latestRelease,
            caddyUpdateStatus: caddyUpdateStatus,
            caddyRuntimeStatus: caddyRuntimeStatus,
            tlsStatus: tlsStatus,
            configPreview: configPreview,
            runtimeTargets: runtimeTargets,
            onDemandAppStatuses: onDemandAppStatuses,
            discoveredMultipassServices: discoveredMultipassServices,
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
        let discoveredMultipassServices = await onDemandAppsService.discoverMultipassServicesFromYAML()
        let effectiveMultipassServices = mergedMultipassServices(
            savedServices: appConfig.multipassServices,
            discoveredServices: discoveredMultipassServices
        )
        let multipassServiceStatuses = await onDemandAppsService.multipassStatuses()
        let routes = configService.routes(
            runtimeTargets: runtimeTargets,
            customRoutes: appConfig.customRoutes,
            onDemandApps: appConfig.onDemandApps,
            multipassServices: effectiveMultipassServices
        )
        let configPreview = configService.preview(
            for: routes,
            additionalCaddyfileConfig: appConfig.additionalCaddyfileConfig,
            enableTraefikMeAliases: appConfig.enableTraefikMeAliases
        )
        let caddyRuntimeStatus = configLifecycleService.runtimeStatus()
        let runtimeCommandIssues = ShellCommandBackoffStore.shared.dashboardIssues()
        let warnings = DashboardWarningsBuilder.build(
            caddyInstall: snapshot.caddyInstall,
            tlsStatus: snapshot.tlsStatus,
            runtimeTargets: runtimeTargets,
            autoSetupReport: snapshot.autoSetupReport,
            runtimeCommandIssues: runtimeCommandIssues
        )

        return DashboardSnapshot(
            generatedAt: Date(),
            caddyInstall: snapshot.caddyInstall,
            latestRelease: snapshot.latestRelease,
            caddyUpdateStatus: snapshot.caddyUpdateStatus,
            caddyRuntimeStatus: caddyRuntimeStatus,
            tlsStatus: snapshot.tlsStatus,
            configPreview: configPreview,
            runtimeTargets: runtimeTargets,
            onDemandAppStatuses: onDemandAppStatuses,
            discoveredMultipassServices: discoveredMultipassServices,
            multipassServiceStatuses: multipassServiceStatuses,
            routes: routes,
            warnings: warnings,
            autoSetupReport: snapshot.autoSetupReport
        )
    }

    private func mergedMultipassServices(
        savedServices: [MultipassServiceDraft],
        discoveredServices: [MultipassServiceDraft]
    ) -> [MultipassServiceDraft] {
        var mergedByKey = Dictionary(uniqueKeysWithValues: discoveredServices.map { ($0.configurationKey, $0) })
        for service in savedServices {
            mergedByKey[service.configurationKey] = service
        }
        return mergedByKey.values.sorted {
            if $0.vmName.caseInsensitiveCompare($1.vmName) != .orderedSame {
                return $0.vmName.localizedCaseInsensitiveCompare($1.vmName) == .orderedAscending
            }
            return $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
        }
    }
}
