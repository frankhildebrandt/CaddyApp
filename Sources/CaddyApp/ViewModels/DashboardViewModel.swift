import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    private static let runtimePollIntervalNanoseconds: UInt64 = 5_000_000_000

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
    @Published var customAdditionalCaddyfileConfig: String
    @Published private(set) var isSavingCustomConfig = false
    @Published private(set) var lastCustomConfigSaveResult: CustomConfigSaveResult?
    @Published private(set) var customConfigValidationError: String?
    @Published private(set) var appLogText: String = ""
    @Published private(set) var isRefreshingLogs = false
    @Published var logFilterQuery: String = ""
    @Published private(set) var isChangingOnDemandAppRuntime = false
    @Published private(set) var lastOnDemandAppControlResult: OnDemandAppControlResult?

    private let dashboardService: DashboardService
    private let configLifecycleService: CaddyConfigLifecycleService
    private let tlsService: LocalhostTLSService
    private let caddyInstallationService: CaddyInstallationService
    private let customConfigStore: CustomConfigStore
    private let onDemandAppsService: OnDemandAppsService
    private let shellRunner = ShellCommandRunner()
    private var hasLoaded = false
    private var lastGeneratedConfigFingerprint: Int?
    private var refreshPendingAfterRuntimeChange = false
    private var runtimePollingTask: Task<Void, Never>?

    init(
        dashboardService: DashboardService,
        configLifecycleService: CaddyConfigLifecycleService = CaddyConfigLifecycleService(),
        tlsService: LocalhostTLSService = LocalhostTLSService(),
        caddyInstallationService: CaddyInstallationService = CaddyInstallationService(),
        customConfigStore: CustomConfigStore = CustomConfigStore(),
        onDemandAppsService: OnDemandAppsService = .shared
    ) {
        let initialCustomConfig = customConfigStore.load()
        self.dashboardService = dashboardService
        self.configLifecycleService = configLifecycleService
        self.tlsService = tlsService
        self.caddyInstallationService = caddyInstallationService
        self.customConfigStore = customConfigStore
        self.onDemandAppsService = onDemandAppsService
        self.customRoutes = initialCustomConfig.customRoutes
        self.onDemandApps = initialCustomConfig.onDemandApps
        self.customAdditionalCaddyfileConfig = initialCustomConfig.additionalCaddyfileConfig
    }

    static func bootstrap() -> DashboardViewModel {
        DashboardViewModel(dashboardService: DashboardService())
    }

    deinit {
        runtimePollingTask?.cancel()
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
                ? self.configLifecycleService.start(preview: snapshot.configPreview)
                : self.configLifecycleService.stop()
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
            let result = self.tlsService.trustLocalCAWithSystemPrompt()
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
            let result = self.caddyInstallationService.updateViaHomebrew()
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
        var app = preset.app
        let existingHosts = Set(onDemandApps.map { $0.host.lowercased() })
        if existingHosts.contains(app.host.lowercased()) {
            let baseHost = app.host.replacingOccurrences(of: ".localhost", with: "")
            var suffix = 2
            while existingHosts.contains("\(baseHost)\(suffix).localhost".lowercased()) {
                suffix += 1
            }
            app.host = "\(baseHost)\(suffix).localhost"
            app.unitName = "\(app.unitName)-\(suffix)"
            app.name = "\(app.name) \(suffix)"
        }
        onDemandApps.append(app)
    }

    func removeOnDemandApp(id: OnDemandAppDraft.ID) {
        onDemandApps.removeAll { $0.id == id }
    }

    func saveCustomConfig() {
        guard !isSavingCustomConfig else { return }
        let existingSettings = customConfigStore.load()

        let normalizedRoutes = customRoutes.map { route in
            CustomRouteDraft(
                id: route.id,
                host: route.host.trimmingCharacters(in: .whitespacesAndNewlines),
                upstream: route.upstream.trimmingCharacters(in: .whitespacesAndNewlines),
                enabled: route.enabled
            )
        }
        let normalizedOnDemandApps = onDemandApps.map { app in
            var normalized = app
            normalized.name = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.host = app.host.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.unitName = app.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.targetHost = app.targetHost.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.runArguments = app.runArguments.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.healthPath = app.healthPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized
        }

        if let validationError = validateCustomConfig(routes: normalizedRoutes) {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: validationError,
                performedAt: Date()
            )
            return
        }
        if let validationError = validateOnDemandApps(normalizedOnDemandApps, existingHosts: normalizedRoutes.map(\.host)) {
            customConfigValidationError = validationError
            lastCustomConfigSaveResult = CustomConfigSaveResult(
                succeeded: false,
                message: validationError,
                performedAt: Date()
            )
            return
        }

        customRoutes = normalizedRoutes
        onDemandApps = normalizedOnDemandApps
        customConfigValidationError = nil
        isSavingCustomConfig = true
        let removedOnDemandApps = existingSettings.onDemandApps.filter { previous in
            !normalizedOnDemandApps.contains(where: { $0.id == previous.id })
        }
        let settings = CustomConfigSettings(
            customRoutes: normalizedRoutes,
            onDemandApps: normalizedOnDemandApps,
            additionalCaddyfileConfig: customAdditionalCaddyfileConfig
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                try self.customConfigStore.save(settings)
                let cleanupResults = await self.onDemandAppsService.deleteRuntimeUnits(for: removedOnDemandApps)
                let cleanupFailures = cleanupResults.filter { !$0.succeeded }
                let cleanupSummary: String
                if removedOnDemandApps.isEmpty {
                    cleanupSummary = ""
                } else if cleanupFailures.isEmpty {
                    cleanupSummary = " Entfernte On-Demand-Container/Pods wurden ebenfalls gelöscht."
                } else {
                    cleanupSummary = " Hinweis: \(cleanupFailures.count) Runtime-Unit(s) konnten nicht gelöscht werden."
                }
                self.lastCustomConfigSaveResult = CustomConfigSaveResult(
                    succeeded: true,
                    message: "Custom routes/config lokal gespeichert. Snapshot wird aktualisiert (Auto-Reload bei gültiger Config).\(cleanupSummary)",
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
            let updatedSnapshot = await self.dashboardService.loadSnapshot()
            self.snapshot = updatedSnapshot
            self.hasLoaded = true
            self.startRuntimePollingIfNeeded()
            self.refreshLogs()
        }
    }

    func hostLogText(for app: OnDemandAppDraft) -> String {
        let raw = AppLogService.readLog()
        let needles = [
            "host=\(app.host.lowercased())",
            "app=\(app.name.lowercased())",
            app.host.lowercased()
        ]
        return filterLogLines(raw, containsAny: needles)
    }

    func eventLogText(for app: OnDemandAppDraft) -> String {
        let raw = AppLogService.readLog()
        let appNeedles = [
            "app=\(app.name.lowercased())",
            "unit=\(app.unitKind.rawValue):\(app.unitName.lowercased())",
            app.unitName.lowercased(),
            app.host.lowercased()
        ]
        let eventNeedles = [
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
        return raw
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
        return await Task.detached(priority: .userInitiated) { [shellRunner] in
            let command: String
            switch app.unitKind {
            case .container:
                command = "\(app.runtime.rawValue) logs --tail \(tailLines) \(unit)"
            case .pod:
                command = "\(app.runtime.rawValue) pod logs --tail \(tailLines) \(unit)"
            }
            let result = shellRunner.runShell(command)
            let text = [result.stdout, result.stderr]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                return "Keine Ausgabe vorhanden."
            }
            return text
        }.value
    }

    func runShellCommandInApp(_ command: String, app: OnDemandAppDraft) async -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Bitte einen Befehl eingeben." }
        let unit = shellEscape(app.unitName)
        let shellCommand = shellEscape(trimmed)
        return await Task.detached(priority: .userInitiated) { [shellRunner] in
            let runtimeCommand: String
            switch app.unitKind {
            case .container:
                runtimeCommand = "\(app.runtime.rawValue) exec \(unit) sh -lc \(shellCommand)"
            case .pod:
                runtimeCommand = "\(app.runtime.rawValue) pod exec \(unit) sh -lc \(shellCommand)"
            }
            let result = shellRunner.runShell(runtimeCommand)
            let output = [result.stdout, result.stderr]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return "Befehl ausgeführt (keine Ausgabe). Exit-Code: \(result.exitCode)"
            }
            return output
        }.value
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

    private func performConfigOperation(kind: ConfigOperationKind) {
        guard !isApplyingConfig, let preview = snapshot?.configPreview else { return }
        isApplyingConfig = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            let result: ConfigOperationResult
            switch kind {
            case .write:
                result = self.configLifecycleService.write(preview: preview)
            case .validate:
                result = self.configLifecycleService.validate(preview: preview)
            case .reload:
                result = self.configLifecycleService.reload(preview: preview)
            case .start:
                result = self.configLifecycleService.start(preview: preview)
            case .stop:
                result = self.configLifecycleService.stop()
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
                let startResult = configLifecycleService.start(preview: currentSnapshot.configPreview)
                isChangingCaddyRuntime = false
                lastConfigOperation = startResult
                await reloadSnapshotAfterConfigMutation()
                runDeferredRefreshIfNeeded()
            } else if configFileDiffersFromPreview(currentSnapshot.configPreview) {
                let validateResult = configLifecycleService.validate(preview: currentSnapshot.configPreview)
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

                let reloadResult = configLifecycleService.reload(preview: currentSnapshot.configPreview)
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

        let validateResult = configLifecycleService.validate(preview: currentSnapshot.configPreview)
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

        let reloadResult = configLifecycleService.reload(preview: currentSnapshot.configPreview)
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

    private func filterLogLines(_ raw: String, containsAny needles: [String]) -> String {
        raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let lowered = line.lowercased()
                return needles.contains(where: { !$0.isEmpty && lowered.contains($0) })
            }
            .joined(separator: "\n")
    }

    nonisolated private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func validateCustomConfig(routes: [CustomRouteDraft]) -> String? {
        for (index, route) in routes.enumerated() {
            if route.host.isEmpty || route.upstream.isEmpty {
                return "Route \(index + 1): Host und Upstream dürfen nicht leer sein."
            }
            if route.host.contains(where: \.isWhitespace) {
                return "Route \(index + 1): Host darf keine Leerzeichen enthalten."
            }
            if route.upstream.contains(where: \.isWhitespace) {
                return "Route \(index + 1): Upstream darf keine Leerzeichen enthalten."
            }
        }

        let duplicateHosts = Dictionary(grouping: routes.map(\.host)) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateHost = duplicateHosts.first {
            return "Doppelter Host in Custom Routes: \(duplicateHost)"
        }

        return nil
    }

    private func validateOnDemandApps(_ apps: [OnDemandAppDraft], existingHosts: [String]) -> String? {
        let routeHostSet = Set(existingHosts.map { $0.lowercased() })

        for (index, app) in apps.enumerated() {
            let row = index + 1
            if app.name.isEmpty { return "On-Demand App \(row): Name darf nicht leer sein." }
            if app.host.isEmpty { return "On-Demand App \(row): Host darf nicht leer sein." }
            if app.unitName.isEmpty { return "On-Demand App \(row): Container/Pod Name darf nicht leer sein." }
            if app.targetHost.isEmpty { return "On-Demand App \(row): Target Host darf nicht leer sein." }
            if app.targetPort <= 0 || app.targetPort > 65535 { return "On-Demand App \(row): Target Port ist ungültig." }
            if app.idleTimeoutSeconds < 15 { return "On-Demand App \(row): Idle Timeout muss mindestens 15 Sekunden sein." }
            if app.host.contains(where: \.isWhitespace) { return "On-Demand App \(row): Host darf keine Leerzeichen enthalten." }
            if app.targetHost.contains(where: \.isWhitespace) { return "On-Demand App \(row): Target Host darf keine Leerzeichen enthalten." }
            if app.startMode == .runCommand && app.runArguments.isEmpty {
                return "On-Demand App \(row): Run Arguments dürfen im Modus 'Run Command' nicht leer sein."
            }
            if app.runtime == .docker && app.unitKind == .pod {
                return "On-Demand App \(row): Docker unterstützt hier keine Pods. Bitte Container wählen oder Podman nutzen."
            }
            if routeHostSet.contains(app.host.lowercased()) {
                return "On-Demand App \(row): Host kollidiert mit Custom Route: \(app.host)"
            }
        }

        let duplicateHosts = Dictionary(grouping: apps.map { $0.host.lowercased() }) { $0 }
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateHost = duplicateHosts.first {
            return "Doppelter Host in On-Demand Apps: \(duplicateHost)"
        }

        let duplicateUnits = Dictionary(grouping: apps.map { "\($0.runtime.rawValue):\($0.unitKind.rawValue):\($0.unitName.lowercased())" }) { $0 }
            .filter { !$0.key.hasSuffix(":") && $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateUnit = duplicateUnits.first {
            return "Doppelter Runtime/Unit-Name in On-Demand Apps: \(duplicateUnit)"
        }

        return nil
    }

    private func startRuntimePollingIfNeeded() {
        guard runtimePollingTask == nil else { return }
        runtimePollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.runtimePollIntervalNanoseconds)
                guard let self else { break }
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
