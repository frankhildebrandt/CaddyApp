import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    private static let runtimePollIntervalNanoseconds: UInt64 = 8_000_000_000
    private static let draftAutoSaveDebounceNanoseconds: UInt64 = 700_000_000
    private static let repositorySyncInitialDelayNanoseconds: UInt64 = 5_000_000_000
    private static let runtimePollingJobID = "dashboard.runtime-polling"
    private static let draftAutosaveJobID = "dashboard.draft-autosave"
    private static let repositoryAutoSyncJobID = "dashboard.repository-auto-sync"

    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isApplyingConfig = false
    @Published private(set) var isApplyingTLSTrust = false
    @Published private(set) var isUpdatingCaddy = false
    @Published private(set) var isChangingCaddyRuntime = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastConfigOperation: ConfigOperationResult?
    @Published private(set) var lastTrustOperation: SetupOperationResult?
    @Published private(set) var lastCaddyUpdateOperation: CaddyUpdateOperationResult?
    @Published var customRoutes: [CustomRouteDraft]
    @Published var onDemandApps: [OnDemandAppDraft]
    @Published var multipassServices: [MultipassServiceDraft]
    @Published var appRepositories: [AppRepositoryDraft]
    @Published var enableTraefikMeAliases: Bool
    @Published var customAdditionalCaddyfileConfig: String
    @Published private(set) var isSavingCustomConfig = false
    @Published private(set) var lastCustomConfigSaveResult: CustomConfigSaveResult?
    @Published private(set) var customConfigValidationError: String?
    @Published private(set) var appLogText: String = ""
    @Published private(set) var isRefreshingLogs = false
    @Published var logFilterQuery: String = ""
    @Published private(set) var isChangingOnDemandAppRuntime = false
    @Published private(set) var lastOnDemandAppControlResult: OnDemandAppControlResult?
    @Published private(set) var isChangingMultipassServiceRuntime = false
    @Published private(set) var lastMultipassServiceControlResult: OnDemandAppControlResult?
    @Published private(set) var isChangingMultipassVMRuntime = false
    @Published private(set) var lastMultipassVMControlResult: OnDemandAppControlResult?
    @Published private(set) var remoteOnDemandPresets: [OnDemandAppPreset] = []
    @Published private(set) var isRefreshingAppRepositories = false
    @Published private(set) var lastRepositorySyncResult: AppRepositorySyncResult?
    @Published var hideWindowToMenuBarOnClose: Bool
    @Published var repositoryAutoUpdateEnabled: Bool
    @Published var repositoryAutoUpdateIntervalHours: Int
    @Published private(set) var lastSuccessfulRepositorySyncAt: Date?
    @Published private(set) var lastRepositorySyncError: String?

    private let dashboardService: DashboardService
    nonisolated private let configLifecycleService: CaddyConfigLifecycleService
    nonisolated private let tlsService: LocalhostTLSService
    nonisolated private let caddyInstallationService: CaddyInstallationService
    private let appConfigStore: AppConfigStore
    private let onDemandAppsService: OnDemandAppsService
    private let appRepositoryService: AppRepositoryService
    nonisolated private let shellRunner = ShellCommandRunner()
    private let scheduler = InternalScheduler()
    private var hasLoaded = false
    private var lastGeneratedConfigFingerprint: Int?
    private var refreshPendingAfterRuntimeChange = false
    private var hasLoadedRepositoryPresets = false

    init(
        dashboardService: DashboardService,
        configLifecycleService: CaddyConfigLifecycleService = CaddyConfigLifecycleService(),
        tlsService: LocalhostTLSService = LocalhostTLSService(),
        caddyInstallationService: CaddyInstallationService = CaddyInstallationService(),
        appConfigStore: AppConfigStore = AppConfigStore(),
        onDemandAppsService: OnDemandAppsService = .shared,
        appRepositoryService: AppRepositoryService = AppRepositoryService()
    ) {
        let initialAppConfig = appConfigStore.load()
        self.dashboardService = dashboardService
        self.configLifecycleService = configLifecycleService
        self.tlsService = tlsService
        self.caddyInstallationService = caddyInstallationService
        self.appConfigStore = appConfigStore
        self.onDemandAppsService = onDemandAppsService
        self.appRepositoryService = appRepositoryService
        self.customRoutes = initialAppConfig.customRoutes
        self.onDemandApps = initialAppConfig.onDemandApps
        self.multipassServices = initialAppConfig.multipassServices
        self.appRepositories = initialAppConfig.appRepositories
        self.enableTraefikMeAliases = initialAppConfig.enableTraefikMeAliases
        self.customAdditionalCaddyfileConfig = initialAppConfig.additionalCaddyfileConfig
        self.hideWindowToMenuBarOnClose = initialAppConfig.general.hideWindowToMenuBarOnClose
        self.repositoryAutoUpdateEnabled = initialAppConfig.repositorySync.autoUpdateEnabled
        self.repositoryAutoUpdateIntervalHours = initialAppConfig.repositorySync.autoUpdateIntervalHours
        self.lastSuccessfulRepositorySyncAt = initialAppConfig.repositorySync.lastSuccessfulSyncAt
        self.lastRepositorySyncError = initialAppConfig.repositorySync.lastSyncError
        UserDefaults.standard.set(initialAppConfig.general.hideWindowToMenuBarOnClose, forKey: AppWindowController.hideOnClosePreferenceKey)
    }

    static func bootstrap() -> DashboardViewModel {
        DashboardViewModel(dashboardService: DashboardService())
    }

    deinit {
        let ownedScheduler = scheduler
        Task {
            await ownedScheduler.cancelAll()
        }
    }

    func refreshIfNeeded() {
        guard !hasLoaded else { return }
        refresh()
    }

    func refresh() {
        guard !isLoading else { return }
        guard !isChangingCaddyRuntime else {
            refreshPendingAfterRuntimeChange = true
            return
        }
        isLoading = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            self.refreshLogs()
            let previousSnapshot = self.snapshot
            let wasInitialLoad = !self.hasLoaded
            let snapshot = await dashboardService.loadSnapshot()
            self.snapshot = snapshot
            self.isLoading = false
            self.hasLoaded = true
            self.startRuntimePollingIfNeeded()
            self.startRepositoryAutoSyncIfNeeded()
            if !self.hasLoadedRepositoryPresets {
                self.refreshAppRepositoryPresets(trigger: .startup)
            }
            await self.runAutomaticCaddyActionsIfNeeded(
                previousSnapshot: previousSnapshot,
                currentSnapshot: snapshot,
                isInitialLoad: wasInitialLoad
            )
        }
    }

    func writeConfigPreview() {
        performConfigOperation(kind: .write)
    }

    func validateConfigPreview() {
        performConfigOperation(kind: .validate)
    }

    func reloadCaddy() {
        performConfigOperation(kind: .reload)
    }

    func setCaddyRunning(_ shouldRun: Bool) {
        guard !isChangingCaddyRuntime else { return }
        guard let snapshot else { return }
        let current = snapshot.caddyRuntimeStatus.isRunning
        guard current != shouldRun else { return }
        AppLogService.logEvent("Caddy runtime requested: \(shouldRun ? "start" : "stop")")

        isChangingCaddyRuntime = true
        Task { [weak self] in
            guard let self else { return }
            let result: ConfigOperationResult = shouldRun
                ? await self.configLifecycleService.startAsync(preview: snapshot.configPreview)
                : await self.configLifecycleService.stopAsync()
            self.lastConfigOperation = result
            self.isChangingCaddyRuntime = false
            await self.reloadSnapshotAfterConfigMutation()
            self.runDeferredRefreshIfNeeded()
        }
    }

    func trustLocalCA() {
        guard !isApplyingTLSTrust else { return }
        isApplyingTLSTrust = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            let result = await self.tlsService.trustLocalCAWithSystemPromptAsync()
            self.lastTrustOperation = result
            self.isApplyingTLSTrust = false
            if result.succeeded {
                self.refresh()
            }
        }
    }

    func updateCaddy() {
        guard !isUpdatingCaddy else { return }
        isUpdatingCaddy = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            let result = await self.caddyInstallationService.updateViaHomebrewAsync()
            self.lastCaddyUpdateOperation = result
            self.isUpdatingCaddy = false
            await self.refreshAfterCaddyUpdateIfNeeded(result)
        }
    }

    func addCustomRoute() {
        customRoutes.append(CustomRouteDraft(host: "", upstream: "", enabled: true))
    }

    func removeCustomRoute(id: CustomRouteDraft.ID) {
        customRoutes.removeAll { $0.id == id }
    }

    func addOnDemandApp() {
        onDemandApps.append(
            OnDemandAppDraft(
                name: "",
                runtime: .podman,
                unitKind: .container,
                unitName: "",
                host: "",
                targetPort: 3000,
                idleTimeoutSeconds: 600,
                enabled: true,
                startMode: .runCommand,
                runArguments: "",
                healthPath: "/"
            )
        )
    }

    func addOnDemandPreset(_ preset: OnDemandAppPreset) {
        onDemandApps.append(preset.app.uniquedForInsert(existingApps: onDemandApps))
    }

    func removeOnDemandApp(id: OnDemandAppDraft.ID) {
        onDemandApps.removeAll { $0.id == id }
    }

    func addMultipassService() {
        multipassServices.append(
            MultipassServiceDraft(
                vmName: "",
                serviceName: "",
                host: "",
                targetPort: 8080
            )
        )
    }

    func addMultipassService(_ draft: MultipassServiceDraft) {
        multipassServices.append(draft.normalized())
    }

    func addMultipassService(forVMName vmName: String) {
        let defaultService = MultipassServiceDraft.defaultForVM(vmName, existingServices: multipassServices)
        if defaultService.vmName.isEmpty {
            addMultipassService()
            return
        }
        multipassServices.append(defaultService)
    }

    func removeMultipassService(id: MultipassServiceDraft.ID) {
        multipassServices.removeAll { $0.id == id }
    }

    func addAppRepository() {
        appRepositories.append(
            AppRepositoryDraft(
                name: "Neues Repository",
                entryURL: "",
                enabled: true
            )
        )
    }

    func removeAppRepository(id: AppRepositoryDraft.ID) {
        appRepositories.removeAll { $0.id == id }
    }

    func moveAppRepositoryUp(id: AppRepositoryDraft.ID) {
        guard let index = appRepositories.firstIndex(where: { $0.id == id }), index > 0 else { return }
        appRepositories.swapAt(index, index - 1)
    }

    func moveAppRepositoryDown(id: AppRepositoryDraft.ID) {
        guard let index = appRepositories.firstIndex(where: { $0.id == id }), index < appRepositories.count - 1 else { return }
        appRepositories.swapAt(index, index + 1)
    }

    enum RepositorySyncTrigger: Equatable {
        case manual
        case startup
        case automatic
    }

    func refreshAppRepositoryPresets(trigger: RepositorySyncTrigger = .manual) {
        guard !isRefreshingAppRepositories else { return }
        isRefreshingAppRepositories = true
        Task { [weak self] in
            guard let self else { return }
            let sync = await self.appRepositoryService.syncPresets(from: self.appRepositories)
            self.remoteOnDemandPresets = sync.presets
            self.lastRepositorySyncResult = sync.result
            self.isRefreshingAppRepositories = false
            self.hasLoadedRepositoryPresets = true
            self.applyRepositorySyncResult(sync.result, trigger: trigger)
        }
    }

    func scheduleDraftAutoSave() {
        guard hasLoaded else { return }
        Task { [weak self] in
            guard let self else { return }
            await scheduler.scheduleDebounced(
                id: Self.draftAutosaveJobID,
                delayNanoseconds: Self.draftAutoSaveDebounceNanoseconds
            ) { [weak self] in
                guard let self else { return }
                await self.saveRouteAndOnDemandDraftsIfNeeded()
            }
        }
    }

    func saveAdditionalCaddyfileConfig() {
        guard !isSavingCustomConfig else { return }
        let existingConfig = appConfigStore.load()
        let additionalConfig = customAdditionalCaddyfileConfig
            .trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingCustomConfig = true
        Task { [weak self] in
            guard let self else { return }
            do {
                var config = existingConfig
                config.routing = AppRoutingSettings(
                    enableTraefikMeAliases: enableTraefikMeAliases,
                    additionalCaddyfileConfig: additionalConfig
                )
                config.appRepositories = appRepositories
                config.general.hideWindowToMenuBarOnClose = hideWindowToMenuBarOnClose
                config.repositorySync.autoUpdateEnabled = repositoryAutoUpdateEnabled
                config.repositorySync.autoUpdateIntervalHours = repositoryAutoUpdateIntervalHours
                try self.appConfigStore.save(config)
                self.customAdditionalCaddyfileConfig = additionalConfig
                self.customConfigValidationError = nil
                self.lastCustomConfigSaveResult = CustomConfigSaveResult(
                    succeeded: true,
                    message: "Zusätzliche Caddyfile-Config gespeichert. Snapshot wird aktualisiert (Auto-Reload bei gültiger Config).",
                    performedAt: Date()
                )
                self.isSavingCustomConfig = false
                self.refresh()
            } catch {
                self.lastCustomConfigSaveResult = CustomConfigSaveResult(
                    succeeded: false,
                    message: "Speichern fehlgeschlagen: \(error.localizedDescription)",
                    performedAt: Date()
                )
                self.isSavingCustomConfig = false
            }
        }
    }

    private func saveRouteAndOnDemandDraftsIfNeeded() async {
        guard !isSavingCustomConfig else { return }
        let existingConfig = appConfigStore.load()
        let normalizedBundle = CustomConfigDraftBundle(
            routes: customRoutes,
            onDemandApps: onDemandApps,
            multipassServices: multipassServices,
            appRepositories: appRepositories
        ).normalized()
        let normalizedRoutes = normalizedBundle.routes
        let normalizedOnDemandApps = normalizedBundle.onDemandApps
        let normalizedMultipassServices = normalizedBundle.multipassServices
        let normalizedRepositories = normalizedBundle.appRepositories

        if let validationError = normalizedBundle.validateRoutes()?.localizedDescription {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: validationError,
                performedAt: Date()
            )
            return
        }
        if let validationError = normalizedBundle.validateOnDemandApps(existingRouteHosts: normalizedRoutes.map(\.host))?.localizedDescription {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: "Auto-Save pausiert: \(validationError)",
                performedAt: Date()
            )
            return
        }
        if let validationError = normalizedBundle.validateMultipassServices(
            existingHosts: normalizedRoutes.map(\.host) + normalizedOnDemandApps.map(\.host)
        )?.localizedDescription {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: "Auto-Save pausiert: \(validationError)",
                performedAt: Date()
            )
            return
        }
        if let validationError = normalizedBundle.validateRepositories()?.localizedDescription {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: "Auto-Save pausiert: \(validationError)",
                performedAt: Date()
            )
            return
        }

        if normalizedRoutes == existingConfig.customRoutes,
           normalizedOnDemandApps == existingConfig.onDemandApps,
           normalizedMultipassServices == existingConfig.multipassServices,
           normalizedRepositories == existingConfig.appRepositories,
           enableTraefikMeAliases == existingConfig.enableTraefikMeAliases,
           hideWindowToMenuBarOnClose == existingConfig.general.hideWindowToMenuBarOnClose,
           repositoryAutoUpdateEnabled == existingConfig.repositorySync.autoUpdateEnabled,
           repositoryAutoUpdateIntervalHours == existingConfig.repositorySync.autoUpdateIntervalHours
        {
            return
        }

        customRoutes = normalizedRoutes
        onDemandApps = normalizedOnDemandApps
        multipassServices = normalizedMultipassServices
        appRepositories = normalizedRepositories
        customConfigValidationError = nil
        isSavingCustomConfig = true
        UserDefaults.standard.set(hideWindowToMenuBarOnClose, forKey: AppWindowController.hideOnClosePreferenceKey)
        let removedOnDemandApps = existingConfig.onDemandApps.filter { previous in
            !normalizedOnDemandApps.contains(where: { $0.id == previous.id })
        }
        var config = existingConfig
        config.customRoutes = normalizedRoutes
        config.onDemandApps = normalizedOnDemandApps
        config.multipassServices = normalizedMultipassServices
        config.appRepositories = normalizedRepositories
        config.routing = AppRoutingSettings(
            enableTraefikMeAliases: enableTraefikMeAliases,
            additionalCaddyfileConfig: customAdditionalCaddyfileConfig
        )
        config.general.hideWindowToMenuBarOnClose = hideWindowToMenuBarOnClose
        config.repositorySync.autoUpdateEnabled = repositoryAutoUpdateEnabled
        config.repositorySync.autoUpdateIntervalHours = repositoryAutoUpdateIntervalHours

        do {
            try appConfigStore.save(config)
            let cleanupResults = await onDemandAppsService.deleteRuntimeUnits(for: removedOnDemandApps)
            let cleanupFailures = cleanupResults.filter { !$0.succeeded }
            let cleanupSummary: String
            if removedOnDemandApps.isEmpty {
                cleanupSummary = ""
            } else if cleanupFailures.isEmpty {
                cleanupSummary = " Entfernte On-Demand-Container/Pods wurden ebenfalls gelöscht."
            } else {
                cleanupSummary = " Hinweis: \(cleanupFailures.count) Runtime-Unit(s) konnten nicht gelöscht werden."
            }
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: true,
                message: "Custom Routes/On-Demand-Änderungen automatisch gespeichert.\(cleanupSummary)",
                performedAt: Date()
            )
            isSavingCustomConfig = false
            refresh()
        } catch {
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: "Auto-Save fehlgeschlagen: \(error.localizedDescription)",
                performedAt: Date()
            )
            isSavingCustomConfig = false
        }
    }

    func refreshLogs() {
        guard !isRefreshingLogs else { return }
        isRefreshingLogs = true
        Task { [weak self] in
            guard let self else { return }
            let text = AppLogService.readLog()
            self.appLogText = text
            self.isRefreshingLogs = false
        }
    }

    func clearLogs() {
        do {
            try AppLogService.clearLog()
            appLogText = ""
            AppLogService.logEvent("Log file cleared by user")
            refreshLogs()
        } catch {
            lastError = "Logs konnten nicht gelöscht werden: \(error.localizedDescription)"
            AppLogService.logError(lastError ?? "Log clear failed")
        }
    }

    func setOnDemandAppRunning(appID: UUID, shouldRun: Bool) {
        guard !isChangingOnDemandAppRuntime else { return }
        isChangingOnDemandAppRuntime = true
        AppLogService.logEvent("On-demand runtime requested manually: \(shouldRun ? "start" : "stop") appID=\(appID.uuidString)")
        Task { [weak self] in
            guard let self else { return }
            let result = shouldRun
                ? await self.onDemandAppsService.startApp(id: appID)
                : await self.onDemandAppsService.stopApp(id: appID)
            self.lastOnDemandAppControlResult = result
            self.isChangingOnDemandAppRuntime = false
            await self.reloadSnapshotAndRefreshLogs()
        }
    }

    func controlMultipassService(serviceID: UUID, action: MultipassServiceControlAction) {
        guard !isChangingMultipassServiceRuntime else { return }
        isChangingMultipassServiceRuntime = true
        Task { [weak self] in
            guard let self else { return }
            let result = await self.onDemandAppsService.controlMultipassService(id: serviceID, action: action)
            self.lastMultipassServiceControlResult = result
            self.isChangingMultipassServiceRuntime = false
            await self.reloadSnapshotAndRefreshLogs()
        }
    }

    func controlMultipassVM(vmName: String, action: MultipassVMControlAction) {
        guard !isChangingMultipassVMRuntime else { return }
        isChangingMultipassVMRuntime = true
        Task { [weak self] in
            guard let self else { return }
            let result = await self.onDemandAppsService.controlMultipassVM(vmName: vmName, action: action)
            self.lastMultipassVMControlResult = result
            self.isChangingMultipassVMRuntime = false
            await self.reloadSnapshotAndRefreshLogs()
        }
    }

    func hostLogText(for app: OnDemandAppDraft) -> String {
        AppLogFilter.filter(appLogText, containsAny: app.hostLogNeedles)
    }

    func eventLogText(for app: OnDemandAppDraft) -> String {
        let appNeedles = app.eventLogNeedles
        let eventNeedles = OnDemandAppDraft.eventActionNeedles
        return appLogText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let lowered = line.lowercased()
                return appNeedles.contains(where: { lowered.contains($0) })
                    && eventNeedles.contains(where: { lowered.contains($0) })
            }
            .joined(separator: "\n")
    }

    func fetchContainerLogText(for app: OnDemandAppDraft, tailLines: Int = 200) async -> String {
        let unit = shellEscape(app.unitName)
        let command: String
        switch app.unitKind {
        case .container:
            command = "\(app.runtime.rawValue) logs --tail \(tailLines) \(unit)"
        case .pod:
            command = "\(app.runtime.rawValue) pod logs --tail \(tailLines) \(unit)"
        }
        let result = await shellRunner.runShellAsync(command)
        let text = [result.stdout, result.stderr]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "Keine Ausgabe vorhanden."
        }
        return text
    }

    func runShellCommandInApp(_ command: String, app: OnDemandAppDraft) async -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Bitte einen Befehl eingeben." }
        let unit = shellEscape(app.unitName)
        let shellCommand = shellEscape(trimmed)
        let runtimeCommand: String
        switch app.unitKind {
        case .container:
            runtimeCommand = "\(app.runtime.rawValue) exec \(unit) sh -lc \(shellCommand)"
        case .pod:
            runtimeCommand = "\(app.runtime.rawValue) pod exec \(unit) sh -lc \(shellCommand)"
        }
        let result = await shellRunner.runShellAsync(runtimeCommand)
        let output = [result.stdout, result.stderr]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
            return "Befehl ausgeführt (keine Ausgabe). Exit-Code: \(result.exitCode)"
        }
        return output
    }

    func openInteractiveShellForOnDemandApp(_ app: OnDemandAppDraft) -> OnDemandAppControlResult {
        let unit = app.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else {
            return OnDemandAppControlResult(
                succeeded: false,
                message: "Container/Pod Name fehlt.",
                performedAt: Date()
            )
        }

        let escapedUnit = shellEscape(unit)
        let shellSequence: String
        switch app.unitKind {
        case .container:
            shellSequence = """
            \(app.runtime.rawValue) exec -it \(escapedUnit) /bin/sh || \
            \(app.runtime.rawValue) exec -it \(escapedUnit) sh || \
            \(app.runtime.rawValue) exec -it \(escapedUnit) /bin/bash || \
            \(app.runtime.rawValue) exec -it \(escapedUnit) bash
            """
        case .pod:
            shellSequence = """
            \(app.runtime.rawValue) pod exec -it \(escapedUnit) /bin/sh || \
            \(app.runtime.rawValue) pod exec -it \(escapedUnit) sh || \
            \(app.runtime.rawValue) pod exec -it \(escapedUnit) /bin/bash || \
            \(app.runtime.rawValue) pod exec -it \(escapedUnit) bash
            """
        }

        let escapedAppleScriptCommand = shellSequence
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let result = shellRunner.run(
            "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"Terminal\" to activate",
                "-e", "tell application \"Terminal\" to do script \"\(escapedAppleScriptCommand)\""
            ]
        )
        let succeeded = result.isSuccess
        let message = succeeded
            ? "Interaktive Shell in Terminal geöffnet."
            : ([result.stderr, result.stdout]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines))
        return OnDemandAppControlResult(
            succeeded: succeeded,
            message: message.isEmpty ? "Shell konnte nicht geöffnet werden." : message,
            performedAt: Date()
        )
    }

    private func refreshAfterCaddyUpdateIfNeeded(_ result: CaddyUpdateOperationResult) async {
        guard result.succeeded || result.recoverySucceeded == true else { return }
        let snapshot = await dashboardService.loadSnapshot()
        self.snapshot = snapshot
        self.hasLoaded = true
        self.startRuntimePollingIfNeeded()
    }

    var repositorySyncStatusText: String {
        if isRefreshingAppRepositories {
            return "Feed-Sync läuft"
        }
        if let lastRepositorySyncError, !lastRepositorySyncError.isEmpty {
            return "Feed-Sync fehlerhaft"
        }
        if let lastSuccessfulRepositorySyncAt {
            return "Letzter Sync \(lastSuccessfulRepositorySyncAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return repositoryAutoUpdateEnabled ? "Auto-Sync aktiv" : "Auto-Sync aus"
    }

    private func startRepositoryAutoSyncIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            if !repositoryAutoUpdateEnabled {
                await scheduler.cancel(id: Self.repositoryAutoSyncJobID)
                return
            }
            let interval = UInt64(max(repositoryAutoUpdateIntervalHours, 1)) * 3_600_000_000_000
            await scheduler.scheduleRepeating(
                id: Self.repositoryAutoSyncJobID,
                intervalNanoseconds: interval,
                initialDelayNanoseconds: Self.repositorySyncInitialDelayNanoseconds,
                policy: .replace
            ) { [weak self] in
                await MainActor.run {
                    self?.refreshAppRepositoryPresets(trigger: .automatic)
                }
            }
        }
    }

    private func applyRepositorySyncResult(_ result: AppRepositorySyncResult, trigger: RepositorySyncTrigger) {
        let existingConfig = appConfigStore.load()
        var config = existingConfig
        if result.succeeded {
            lastSuccessfulRepositorySyncAt = result.performedAt
            lastRepositorySyncError = nil
            config.repositorySync.lastSuccessfulSyncAt = result.performedAt
            config.repositorySync.lastSyncError = nil
        } else {
            let message = result.warnings.first ?? result.message
            lastRepositorySyncError = message
            config.repositorySync.lastSyncError = message
        }
        config.repositorySync.lastLoadedPresetCount = result.loadedPresetCount
        config.repositorySync.lastLoadedRepositoryCount = result.loadedRepositoryCount
        config.repositorySync.autoUpdateEnabled = repositoryAutoUpdateEnabled
        config.repositorySync.autoUpdateIntervalHours = repositoryAutoUpdateIntervalHours
        try? appConfigStore.save(config)
        if trigger != .manual {
            startRepositoryAutoSyncIfNeeded()
        }
    }

    private func performConfigOperation(kind: ConfigOperationKind) {
        guard !isApplyingConfig, let preview = snapshot?.configPreview else { return }
        isApplyingConfig = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            let result: ConfigOperationResult
            switch kind {
            case .write:
                result = await self.configLifecycleService.writeAsync(preview: preview)
            case .validate:
                result = await self.configLifecycleService.validateAsync(preview: preview)
            case .reload:
                result = await self.configLifecycleService.reloadAsync(preview: preview)
            case .start:
                result = await self.configLifecycleService.startAsync(preview: preview)
            case .stop:
                result = await self.configLifecycleService.stopAsync()
            case .autoApply:
                result = ConfigOperationResult(
                    kind: .autoApply,
                    succeeded: false,
                    message: "Auto-apply is triggered internally only",
                    output: "",
                    performedAt: Date()
                )
            }

            self.lastConfigOperation = result
            self.isApplyingConfig = false
            if result.succeeded || kind == .reload || kind == .start || kind == .stop {
                await self.reloadSnapshotAfterConfigMutation()
            }
        }
    }

    private func runAutomaticCaddyActionsIfNeeded(
        previousSnapshot: DashboardSnapshot?,
        currentSnapshot: DashboardSnapshot,
        isInitialLoad: Bool
    ) async {
        guard currentSnapshot.caddyInstall.isInstalled else { return }

        let currentFingerprint = currentSnapshot.configPreview.generatedCaddyfile.hashValue
        defer { lastGeneratedConfigFingerprint = currentFingerprint }

        if isInitialLoad {
            if !currentSnapshot.caddyRuntimeStatus.isRunning {
                AppLogService.logEvent("Caddy auto-start on initial load (runtime not running)")
                isChangingCaddyRuntime = true
                let startResult = await self.configLifecycleService.startAsync(preview: currentSnapshot.configPreview)
                isChangingCaddyRuntime = false
                lastConfigOperation = startResult
                await reloadSnapshotAfterConfigMutation()
                runDeferredRefreshIfNeeded()
            } else if configFileDiffersFromPreview(currentSnapshot.configPreview) {
                let validateResult = await self.configLifecycleService.validateAsync(preview: currentSnapshot.configPreview)
                if !validateResult.succeeded {
                    lastConfigOperation = ConfigOperationResult(
                        kind: .autoApply,
                        succeeded: false,
                        message: "Auto-reload skipped on startup: generated config is invalid",
                        output: validateResult.output.isEmpty ? validateResult.message : validateResult.output,
                        performedAt: Date()
                    )
                    return
                }

                let reloadResult = await self.configLifecycleService.reloadAsync(preview: currentSnapshot.configPreview)
                lastConfigOperation = ConfigOperationResult(
                    kind: .autoApply,
                    succeeded: reloadResult.succeeded,
                    message: reloadResult.succeeded
                        ? "Auto-reloaded Caddy on startup to apply generated config"
                        : "Auto-reload on startup failed",
                    output: reloadResult.output,
                    performedAt: Date()
                )
                await reloadSnapshotAfterConfigMutation()
            }
            return
        }

        let previousFingerprint = lastGeneratedConfigFingerprint
            ?? previousSnapshot?.configPreview.generatedCaddyfile.hashValue
        guard previousFingerprint != currentFingerprint else { return }

        let validateResult = await self.configLifecycleService.validateAsync(preview: currentSnapshot.configPreview)
        if !validateResult.succeeded {
            lastConfigOperation = ConfigOperationResult(
                kind: .autoApply,
                succeeded: false,
                message: "Auto-reload skipped: generated config is invalid",
                output: validateResult.output.isEmpty ? validateResult.message : validateResult.output,
                performedAt: Date()
            )
            return
        }

        let reloadResult = await self.configLifecycleService.reloadAsync(preview: currentSnapshot.configPreview)
        lastConfigOperation = ConfigOperationResult(
            kind: .autoApply,
            succeeded: reloadResult.succeeded,
            message: reloadResult.succeeded
                ? "Auto-reloaded Caddy after valid config update"
                : "Auto-reload after config update failed",
            output: reloadResult.output,
            performedAt: Date()
        )
        await reloadSnapshotAfterConfigMutation()
    }

    private func reloadSnapshotAfterConfigMutation() async {
        let snapshot = await dashboardService.loadSnapshot()
        self.snapshot = snapshot
        self.hasLoaded = true
        self.startRuntimePollingIfNeeded()
    }

    private func reloadSnapshotAndRefreshLogs() async {
        await reloadSnapshotAfterConfigMutation()
        refreshLogs()
    }

    private func runDeferredRefreshIfNeeded() {
        guard refreshPendingAfterRuntimeChange else { return }
        refreshPendingAfterRuntimeChange = false
        refresh()
    }

    private func configFileDiffersFromPreview(_ preview: CaddyConfigPreview) -> Bool {
        let fileURL = URL(fileURLWithPath: preview.caddyfilePath)
        guard let existing = try? String(contentsOf: fileURL, encoding: .utf8) else { return true }
        let normalizedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPreview = preview.generatedCaddyfile.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedExisting != normalizedPreview
    }

    nonisolated private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func startRuntimePollingIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            await scheduler.scheduleRepeating(
                id: Self.runtimePollingJobID,
                intervalNanoseconds: Self.runtimePollIntervalNanoseconds,
                policy: .keepExisting
            ) { [weak self] in
                guard let self else { return }
                await self.runBackgroundRuntimePollTick()
            }
        }
    }

    private func runBackgroundRuntimePollTick() async {
        guard hasLoaded else { return }
        guard !isLoading, !isApplyingConfig, !isChangingCaddyRuntime else { return }
        guard let currentSnapshot = snapshot else { return }

        let updatedSnapshot = await dashboardService.refreshRuntimeDiscovery(on: currentSnapshot)
        snapshot = updatedSnapshot

        await runAutomaticCaddyActionsIfNeeded(
            previousSnapshot: currentSnapshot,
            currentSnapshot: updatedSnapshot,
            isInitialLoad: false
        )
    }

}
