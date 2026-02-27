import Foundation
import Network

actor OnDemandAppsService {
    static let shared = OnDemandAppsService()
    static let gatewayPort: UInt16 = 49215

    private struct AppState {
        var phase: OnDemandAppPhase = .stopped
        var lastAccessAt: Date?
        var lastActionAt: Date?
        var lastError: String?
    }

    private let runner = ShellCommandRunner()
    private let configStore = CustomConfigStore()
    private let listenerQueue = DispatchQueue(label: "caddyapp.on-demand.gateway")
    private var listener: NWListener?
    private var maintenanceTask: Task<Void, Never>?
    private var appsByID: [UUID: OnDemandAppDraft] = [:]
    private var appIDByHost: [String: UUID] = [:]
    private var states: [UUID: AppState] = [:]
    private var startTasks: [UUID: Task<Void, Never>] = [:]

    func startIfNeeded() {
        startListenerIfNeeded()
        startMaintenanceLoopIfNeeded()
    }

    func reloadConfiguration() {
        let config = configStore.load()
        let apps = config.onDemandApps
        appsByID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        appIDByHost = Dictionary(uniqueKeysWithValues: apps.map { (Self.normalizeHostKey($0.host), $0.id) })

        let validIDs = Set(apps.map(\.id))
        states = states.filter { validIDs.contains($0.key) }
        startTasks = startTasks.filter { validIDs.contains($0.key) }
        for app in apps where states[app.id] == nil {
            states[app.id] = AppState(phase: app.enabled ? .stopped : .stopped)
        }
    }

    func statuses() -> [OnDemandAppRuntimeStatus] {
        refreshStatesFromRuntime()
        return appsByID.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { app in
                let state = states[app.id] ?? AppState()
                return OnDemandAppRuntimeStatus(
                    id: app.id,
                    appID: app.id,
                    name: app.name,
                    host: app.host,
                    runtime: app.runtime,
                    unitKind: app.unitKind,
                    phase: app.enabled ? state.phase : .stopped,
                    enabled: app.enabled,
                    idleTimeoutSeconds: app.idleTimeoutSeconds,
                    lastAccessAt: state.lastAccessAt,
                    lastActionAt: state.lastActionAt,
                    lastError: state.lastError
                )
            }
    }

    func startApp(id: UUID) async -> OnDemandAppControlResult {
        guard appsByID[id] != nil else {
            return OnDemandAppControlResult(succeeded: false, message: "App not found", performedAt: Date())
        }
        let result = await ensureStartedAndWarm(appID: id)
        return OnDemandAppControlResult(succeeded: result.succeeded, message: result.message, performedAt: Date())
    }

    func stopApp(id: UUID) async -> OnDemandAppControlResult {
        let result = stop(appID: id, reason: "manual")
        return OnDemandAppControlResult(succeeded: result.succeeded, message: result.message, performedAt: Date())
    }

    func deleteRuntimeUnits(for apps: [OnDemandAppDraft]) -> [OnDemandAppControlResult] {
        apps.map { app in
            deleteRuntimeUnit(app)
        }
    }

    func markConfigSavedAndReload() {
        reloadConfiguration()
    }

    private func startListenerIfNeeded() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let port = NWEndpoint.Port(rawValue: Self.gatewayPort) ?? .any
            let listener = try NWListener(using: parameters, on: port)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    AppLogService.logEvent("On-demand gateway listening on 127.0.0.1:\(Self.gatewayPort)")
                case let .failed(error):
                    AppLogService.logError("On-demand gateway listener failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak listener] connection in
                guard listener != nil else { return }
                AppLogService.logEvent("On-demand gateway accepted connection")
                let handler = OnDemandGatewayConnection(connection: connection, service: self)
                handler.start(on: self.listenerQueue)
            }
            listener.start(queue: listenerQueue)
            self.listener = listener
        } catch {
            AppLogService.logError("On-demand gateway could not start on port \(Self.gatewayPort): \(error.localizedDescription)")
        }
    }

    private func startMaintenanceLoopIfNeeded() {
        guard maintenanceTask == nil else { return }
        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { break }
                await self.stopIdleAppsIfNeeded()
            }
        }
    }

    private func stopIdleAppsIfNeeded() async {
        let now = Date()
        for app in appsByID.values where app.enabled {
            guard let state = states[app.id], state.phase == .running, let lastAccessAt = state.lastAccessAt else { continue }
            let idleSeconds = now.timeIntervalSince(lastAccessAt)
            if idleSeconds >= Double(max(app.idleTimeoutSeconds, 15)) {
                _ = stop(appID: app.id, reason: "idle timeout")
            }
        }
    }

    private func refreshStatesFromRuntime() {
        for app in appsByID.values {
            var state = states[app.id] ?? AppState()
            guard app.enabled else {
                state.phase = .stopped
                states[app.id] = state
                continue
            }

            let running = isRunning(app).isRunning
            if running {
                if state.phase != .starting && state.phase != .stopping {
                    state.phase = .running
                }
            } else if state.phase == .running {
                state.phase = .stopped
            } else if state.phase == .stopping {
                state.phase = .stopped
            } else if state.phase == .starting {
                // Keep transitional state until command/warmup settles.
            } else if state.phase != .error {
                state.phase = .stopped
            }
            states[app.id] = state
        }
    }

    func handleProxyRequest(_ request: HTTPGatewayRequest) async -> HTTPGatewayResponse {
        if request.headers.contains(where: { $0.0.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame && $0.1.lowercased().contains("chunked") }) {
            return .text(status: 501, body: "Chunked request bodies are not supported by the on-demand gateway yet")
        }
        switch await prepareAppForHTTP(request) {
        case let .failure(response):
            return response
        case let .waiting(response):
            return response
        case let .ready(app):
            return await proxy(request, to: app)
        }
    }

    func prepareWebSocketTunnel(for request: HTTPGatewayRequest) async -> WebSocketTunnelPreparationResult {
        switch await prepareApp(for: request) {
        case let .failure(response):
            return .failure(response)
        case let .waiting(response):
            return .failure(response)
        case let .ready(app):
            AppLogService.logEvent("On-demand websocket tunnel prepared: app=\(app.name) target=\(app.targetHost):\(app.targetPort)")
            return .ready(host: app.targetHost, port: app.targetPort)
        }
    }

    private func ensureStartedAndWarm(appID: UUID) async -> ActionResult {
        defer { startTasks[appID] = nil }
        guard let app = appsByID[appID] else {
            return ActionResult(succeeded: false, message: "App not found")
        }

        let runningCheck = isRunning(app)
        if runningCheck.isRunning {
            var state = states[appID] ?? AppState()
            state.phase = .running
            state.lastError = nil
            states[appID] = state
            return await waitForHealth(app)
        }

        var state = states[appID] ?? AppState()
        state.phase = .starting
        state.lastActionAt = Date()
        state.lastError = nil
        states[appID] = state

        let startResult = start(app)
        if !startResult.succeeded {
            AppLogService.logError("On-demand start failed: app=\(app.name) error=\(startResult.message)")
            state.phase = .error
            state.lastActionAt = Date()
            state.lastError = startResult.message
            states[appID] = state
            return startResult
        }
        AppLogService.logEvent("On-demand start command completed: app=\(app.name)")

        let healthResult = await waitForHealth(app)
        if healthResult.succeeded {
            AppLogService.logEvent("On-demand warmup succeeded: app=\(app.name) target=\(app.targetHost):\(app.targetPort)")
        } else {
            AppLogService.logError("On-demand warmup failed: app=\(app.name) error=\(healthResult.message)")
        }
        state = states[appID] ?? AppState()
        state.phase = healthResult.succeeded ? .running : .error
        state.lastActionAt = Date()
        state.lastError = healthResult.succeeded ? nil : healthResult.message
        states[appID] = state
        return healthResult
    }

    private func waitForHealth(_ app: OnDemandAppDraft) async -> ActionResult {
        let healthPath = app.healthPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = healthPath.isEmpty ? "/" : (healthPath.hasPrefix("/") ? healthPath : "/\(healthPath)")
        let urlString = "http://\(app.targetHost):\(app.targetPort)\(normalizedPath)"
        guard let url = URL(string: urlString) else {
            return ActionResult(succeeded: false, message: "Invalid health URL for app '\(app.name)'")
        }

        let deadline = Date().addingTimeInterval(warmupTimeoutSeconds(for: app))
        while Date() < deadline {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200..<500).contains(http.statusCode) {
                    return ActionResult(succeeded: true, message: "App is reachable")
                }
            } catch {
                // Retry during warm-up.
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return ActionResult(succeeded: false, message: "Timed out waiting for \(app.targetHost):\(app.targetPort)")
    }

    private func proxy(_ incoming: HTTPGatewayRequest, to app: OnDemandAppDraft) async -> HTTPGatewayResponse {
        let target = "http://\(app.targetHost):\(app.targetPort)\(incoming.target)"
        guard let url = URL(string: target) else {
            return .text(status: 500, body: "Invalid upstream URL for \(app.name)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = incoming.method
        request.httpBody = incoming.body
        request.timeoutInterval = 60

        for (name, value) in incoming.headers {
            let lower = name.lowercased()
            if ["host", "content-length", "connection", "proxy-connection", "accept-encoding"].contains(lower) { continue }
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue(app.targetHost, forHTTPHeaderField: "Host")
        // Prevent compressed upstream payloads because URLSession may transparently decode,
        // which can otherwise leave mismatched Content-Encoding headers for the browser.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if incoming.body.isEmpty == false {
            request.setValue(String(incoming.body.count), forHTTPHeaderField: "Content-Length")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .text(status: 502, body: "Upstream response was not HTTP")
            }

            var headers: [(String, String)] = []
            for (key, value) in http.allHeaderFields {
                guard let name = key as? String else { continue }
                let lower = name.lowercased()
                if ["transfer-encoding", "connection", "keep-alive", "proxy-connection", "content-encoding", "content-length"].contains(lower) { continue }
                headers.append((name, String(describing: value)))
            }
            headers.append(("Content-Length", String(data.count)))
            headers.append(("Connection", "close"))

            return HTTPGatewayResponse(statusCode: http.statusCode, headers: headers, body: data)
        } catch {
            return .text(status: 502, body: "Proxy request failed: \(error.localizedDescription)")
        }
    }

    private func prepareApp(for request: HTTPGatewayRequest) async -> PreparedAppResult {
        guard let host = request.host else {
            return .failure(.text(status: 400, body: "Missing Host header"))
        }
        let hostKey = Self.normalizeHostKey(host)
        guard let appID = appIDByHost[hostKey], let app = appsByID[appID] else {
            return .failure(.text(status: 404, body: "Unknown on-demand app host: \(host)"))
        }
        guard app.enabled else {
            return .failure(.text(status: 503, body: "On-demand app is disabled"))
        }
        AppLogService.logEvent("On-demand request: host=\(hostKey) method=\(request.method) target=\(request.target) app=\(app.name)")

        let startResult = await ensureStartedAndWarm(appID: appID)
        guard startResult.succeeded else {
            return .failure(.text(status: 502, body: "Failed to start app '\(app.name)': \(startResult.message)"))
        }

        var state = states[appID] ?? AppState()
        state.lastAccessAt = Date()
        state.lastActionAt = Date()
        state.phase = .running
        states[appID] = state
        return .ready(app)
    }

    private func prepareAppForHTTP(_ request: HTTPGatewayRequest) async -> PreparedAppResult {
        guard let host = request.host else {
            return .failure(.text(status: 400, body: "Missing Host header"))
        }
        let hostKey = Self.normalizeHostKey(host)
        guard let appID = appIDByHost[hostKey], let app = appsByID[appID] else {
            return .failure(.text(status: 404, body: "Unknown on-demand app host: \(host)"))
        }
        guard app.enabled else {
            return .failure(.text(status: 503, body: "On-demand app is disabled"))
        }

        AppLogService.logEvent("On-demand HTTP request: host=\(hostKey) method=\(request.method) target=\(request.target) app=\(app.name)")

        var state = states[appID] ?? AppState()
        let runningCheck = isRunning(app)
        if runningCheck.isRunning && state.phase != .starting {
            let warmup = await waitForHealth(app)
            if warmup.succeeded {
                state.lastAccessAt = Date()
                state.lastActionAt = Date()
                state.phase = .running
                state.lastError = nil
                states[appID] = state
                return .ready(app)
            }
            // Keep serving the waiting/status page while the app is not reachable yet.
            // This avoids hard gateway errors for transient warm-up gaps.
            state.phase = .starting
            state.lastError = warmup.message
            state.lastActionAt = Date()
            states[appID] = state
            queueBackgroundStartIfNeeded(appID: appID)
            return .waiting(waitingPageResponse(for: app, phase: state.phase))
        }

        queueBackgroundStartIfNeeded(appID: appID)
        state = states[appID] ?? state
        state.phase = .starting
        state.lastActionAt = Date()
        states[appID] = state
        return .waiting(waitingPageResponse(for: app, phase: state.phase))
    }

    private func queueBackgroundStartIfNeeded(appID: UUID) {
        guard startTasks[appID] == nil else { return }
        startTasks[appID] = Task { [weak self] in
            guard let self else { return }
            _ = await self.ensureStartedAndWarm(appID: appID)
        }
    }

    private func waitingPageResponse(for app: OnDemandAppDraft, phase: OnDemandAppPhase) -> HTTPGatewayResponse {
        let safeName = htmlEscaped(app.name.isEmpty ? "App" : app.name)
        let safeHost = htmlEscaped(app.host)
        let safeRuntime = htmlEscaped(app.runtime.label)
        let safeUnit = htmlEscaped("\(app.unitKind.label): \(app.unitName)")
        let safeTarget = htmlEscaped("\(app.targetHost):\(app.targetPort)")
        let safePhase = htmlEscaped(phase == .starting ? "Starting" : phase.label)

        let html = """
        <!doctype html>
        <html lang="de">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="refresh" content="1">
          <title>\(safeName) startet...</title>
          <style>
            :root {
              --bg: #0b1220;
              --panel: rgba(255,255,255,0.08);
              --line: rgba(255,255,255,0.14);
              --text: #f6f7fb;
              --muted: #c4cad9;
              --accent: #7dd3fc;
              --accent-2: #86efac;
            }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
              color: var(--text);
              font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background:
                radial-gradient(900px 500px at 10% 10%, rgba(125,211,252,.20), transparent 60%),
                radial-gradient(800px 450px at 90% 90%, rgba(134,239,172,.14), transparent 60%),
                linear-gradient(180deg, #0b1220 0%, #121a2b 100%);
              padding: 24px;
            }
            .card {
              width: min(720px, 100%);
              border-radius: 22px;
              padding: 22px;
              background: var(--panel);
              border: 1px solid var(--line);
              backdrop-filter: blur(12px);
              box-shadow: 0 20px 60px rgba(0,0,0,.30);
            }
            .badge {
              display: inline-flex;
              align-items: center;
              gap: 8px;
              padding: 8px 12px;
              border-radius: 999px;
              background: rgba(125,211,252,.12);
              border: 1px solid rgba(125,211,252,.28);
              color: var(--accent);
              font-size: 13px;
              font-weight: 600;
              letter-spacing: .02em;
            }
            .dot {
              width: 8px;
              height: 8px;
              border-radius: 999px;
              background: var(--accent);
              box-shadow: 0 0 0 0 rgba(125,211,252,.65);
              animation: pulse 1.2s ease-out infinite;
            }
            h1 {
              margin: 14px 0 6px;
              font-size: clamp(26px, 4vw, 38px);
              line-height: 1.05;
            }
            p {
              margin: 0;
              color: var(--muted);
              line-height: 1.5;
            }
            .grid {
              margin-top: 16px;
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
              gap: 10px;
            }
            .item {
              border-radius: 14px;
              border: 1px solid var(--line);
              background: rgba(255,255,255,.03);
              padding: 12px;
            }
            .label {
              font-size: 12px;
              color: var(--muted);
              margin-bottom: 4px;
            }
            .value {
              font-size: 14px;
              font-weight: 600;
              word-break: break-word;
            }
            .hint {
              margin-top: 16px;
              display: flex;
              align-items: center;
              justify-content: space-between;
              gap: 10px;
              font-size: 13px;
              color: var(--muted);
              border-top: 1px solid var(--line);
              padding-top: 12px;
            }
            .spinner {
              width: 20px;
              height: 20px;
              border-radius: 999px;
              border: 2px solid rgba(255,255,255,.18);
              border-top-color: var(--accent-2);
              animation: spin .8s linear infinite;
            }
            .reload {
              color: var(--text);
              text-decoration: none;
              border: 1px solid var(--line);
              border-radius: 10px;
              padding: 8px 10px;
              background: rgba(255,255,255,.04);
            }
            @keyframes spin { to { transform: rotate(360deg); } }
            @keyframes pulse {
              0% { box-shadow: 0 0 0 0 rgba(125,211,252,.65); }
              100% { box-shadow: 0 0 0 10px rgba(125,211,252,0); }
            }
          </style>
        </head>
        <body>
          <main class="card">
            <div class="badge"><span class="dot"></span> Bitte warten, die App startet</div>
            <h1>\(safeName)</h1>
            <p>Die Anwendung wird gerade gestartet und vorbereitet. Diese Seite lädt sich automatisch jede Sekunde neu, bis die App bereit ist.</p>
            <section class="grid" aria-label="App Details">
              <div class="item"><div class="label">Host</div><div class="value">\(safeHost)</div></div>
              <div class="item"><div class="label">Status</div><div class="value">\(safePhase)</div></div>
              <div class="item"><div class="label">Runtime</div><div class="value">\(safeRuntime)</div></div>
              <div class="item"><div class="label">Unit</div><div class="value">\(safeUnit)</div></div>
              <div class="item"><div class="label">Ziel</div><div class="value">\(safeTarget)</div></div>
              <div class="item"><div class="label">Retry</div><div class="value">Auto-Reload alle 1s</div></div>
            </section>
            <div class="hint">
              <span style="display:inline-flex;align-items:center;gap:8px;"><span class="spinner" aria-hidden="true"></span> Starte Container/Pod und prüfe Erreichbarkeit...</span>
              <a class="reload" href="">Jetzt neu laden</a>
            </div>
          </main>
          <script>
            setTimeout(() => { window.location.reload(); }, 1000);
          </script>
        </body>
        </html>
        """

        return .html(
            status: 200,
            body: html,
            extraHeaders: [("Cache-Control", "no-store"), ("Refresh", "1")]
        )
    }

    private func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func warmupTimeoutSeconds(for app: OnDemandAppDraft) -> TimeInterval {
        let name = app.name.lowercased()
        let unitName = app.unitName.lowercased()
        if name.contains("ephe") || unitName.contains("ephe") {
            return 180
        }
        if name.contains("kimai") || unitName.contains("kimai") {
            return 120
        }
        if name.contains("penpot") || unitName.contains("penpot") {
            return 180
        }
        return 30
    }

    private func start(_ app: OnDemandAppDraft) -> ActionResult {
        AppLogService.logEvent("On-demand start requested: app=\(app.name) runtime=\(app.runtime.rawValue) unit=\(app.unitKind.rawValue):\(app.unitName) mode=\(app.startMode.rawValue)")
        switch app.startMode {
        case .startExisting:
            let arguments: [String] = switch app.unitKind {
            case .container: ["start", app.unitName]
            case .pod: ["pod", "start", app.unitName]
            }
            let result = runRuntime(app, arguments: arguments)
            return mapCommandResult(result, fallback: "Failed to start \(app.unitKind.label.lowercased()) \(app.unitName)")
        case .runCommand:
            let args = app.runArguments.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !args.isEmpty else {
                return ActionResult(succeeded: false, message: "Run command arguments are empty")
            }
            let result = runner.runShell("\(app.runtime.rawValue) \(args)")
            let mapped = mapCommandResult(result, fallback: "Failed to run start command for \(app.name)")
            if mapped.succeeded {
                return mapped
            }

            // Common preset flow: first request creates via `run -d --name ...`,
            // later requests after idle-stop need `start <name>` because the container already exists.
            AppLogService.logEvent("On-demand run command failed; trying existing start fallback: app=\(app.name)")
            let fallbackArguments: [String] = switch app.unitKind {
            case .container: ["start", app.unitName]
            case .pod: ["pod", "start", app.unitName]
            }
            let fallback = runRuntime(app, arguments: fallbackArguments)
            let fallbackMapped = mapCommandResult(fallback, fallback: "Failed to start existing \(app.unitKind.rawValue) \(app.unitName)")
            if fallbackMapped.succeeded {
                AppLogService.logEvent("On-demand fallback start succeeded: app=\(app.name)")
                return fallbackMapped
            }
            return mapped
        }
    }

    private func stop(appID: UUID, reason _: String) -> ActionResult {
        guard let app = appsByID[appID] else {
            return ActionResult(succeeded: false, message: "App not found")
        }
        AppLogService.logEvent("On-demand stop requested: app=\(app.name) runtime=\(app.runtime.rawValue) unit=\(app.unitKind.rawValue):\(app.unitName)")

        var state = states[appID] ?? AppState()
        state.phase = .stopping
        state.lastActionAt = Date()
        states[appID] = state

        let arguments: [String] = switch app.unitKind {
        case .container: ["stop", app.unitName]
        case .pod: ["pod", "stop", app.unitName]
        }
        let result = runRuntime(app, arguments: arguments)
        let action = mapCommandResult(result, fallback: "Failed to stop \(app.unitKind.label.lowercased()) \(app.unitName)")
        if action.succeeded {
            AppLogService.logEvent("On-demand stop succeeded: app=\(app.name)")
        } else {
            AppLogService.logError("On-demand stop failed: app=\(app.name) error=\(action.message)")
        }
        state = states[appID] ?? AppState()
        state.phase = action.succeeded ? .stopped : .error
        state.lastActionAt = Date()
        state.lastError = action.succeeded ? nil : action.message
        states[appID] = state
        return action
    }

    private func deleteRuntimeUnit(_ app: OnDemandAppDraft) -> OnDemandAppControlResult {
        let unitName = app.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unitName.isEmpty else {
            return OnDemandAppControlResult(
                succeeded: false,
                message: "Unit name is empty",
                performedAt: Date()
            )
        }

        AppLogService.logEvent("On-demand delete requested: app=\(app.name) runtime=\(app.runtime.rawValue) unit=\(app.unitKind.rawValue):\(unitName)")
        startTasks[app.id]?.cancel()
        startTasks[app.id] = nil

        let arguments: [String] = switch app.unitKind {
        case .container: ["rm", "-f", unitName]
        case .pod: ["pod", "rm", "-f", unitName]
        }
        let result = runRuntime(app, arguments: arguments)
        let action = mapDeleteResult(result, app: app, unitName: unitName)

        if action.succeeded {
            AppLogService.logEvent("On-demand delete succeeded: app=\(app.name)")
            appsByID.removeValue(forKey: app.id)
            appIDByHost.removeValue(forKey: Self.normalizeHostKey(app.host))
            states.removeValue(forKey: app.id)
        } else {
            AppLogService.logError("On-demand delete failed: app=\(app.name) error=\(action.message)")
        }
        return OnDemandAppControlResult(succeeded: action.succeeded, message: action.message, performedAt: Date())
    }

    private func isRunning(_ app: OnDemandAppDraft) -> RunningCheckResult {
        switch app.unitKind {
        case .container:
            let result = runRuntime(app, arguments: ["inspect", "-f", "{{.State.Running}}", app.unitName])
            guard result.isSuccess else { return RunningCheckResult(isRunning: false, message: result.stderr) }
            let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return RunningCheckResult(isRunning: text == "true", message: text)
        case .pod:
            let result = runRuntime(app, arguments: ["pod", "inspect", "-f", "{{.State}}", app.unitName])
            guard result.isSuccess else { return RunningCheckResult(isRunning: false, message: result.stderr) }
            let text = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return RunningCheckResult(isRunning: text.contains("running"), message: text)
        }
    }

    private func runRuntime(_ app: OnDemandAppDraft, arguments: [String]) -> CommandResult {
        runner.runShell(([app.runtime.rawValue] + arguments.map(shellEscapeArgument)).joined(separator: " "))
    }

    private func mapCommandResult(_ result: CommandResult, fallback: String) -> ActionResult {
        if result.isSuccess {
            let output = [result.stdout, result.stderr]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ActionResult(succeeded: true, message: output.isEmpty ? "OK" : output)
        }

        let detail = [result.stderr, result.stdout]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ActionResult(succeeded: false, message: detail.isEmpty ? fallback : detail)
    }

    private func mapDeleteResult(_ result: CommandResult, app: OnDemandAppDraft, unitName: String) -> ActionResult {
        if result.isSuccess {
            return mapCommandResult(
                result,
                fallback: "Failed to remove \(app.unitKind.label.lowercased()) \(unitName)"
            )
        }

        let detail = [result.stderr, result.stdout]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isNotFoundDeleteError(detail) {
            return ActionResult(succeeded: true, message: "Already removed")
        }
        return ActionResult(
            succeeded: false,
            message: detail.isEmpty ? "Failed to remove \(app.unitKind.label.lowercased()) \(unitName)" : detail
        )
    }

    private func isNotFoundDeleteError(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("no such container")
            || lowered.contains("no container with name or id")
            || lowered.contains("no such pod")
            || lowered.contains("no pod with name or id")
            || lowered.contains("could not find pod")
            || lowered.contains("not found")
    }

    private func shellEscapeArgument(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func normalizeHostKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: ":")
            .first
            .map(String.init) ?? ""
    }
}

private struct ActionResult {
    var succeeded: Bool
    var message: String
}

private struct RunningCheckResult {
    var isRunning: Bool
    var message: String
}

struct HTTPGatewayRequest {
    var method: String
    var target: String
    var version: String
    var headers: [(String, String)]
    var body: Data

    var host: String? {
        headers.first { $0.0.caseInsensitiveCompare("Host") == .orderedSame }?.1
    }

    var isWebSocketUpgrade: Bool {
        let upgrade = headers.first { $0.0.caseInsensitiveCompare("Upgrade") == .orderedSame }?.1.lowercased()
        let connection = headers.first { $0.0.caseInsensitiveCompare("Connection") == .orderedSame }?.1.lowercased() ?? ""
        return upgrade == "websocket" && connection.contains("upgrade")
    }

    func serializedForForwarding() -> Data {
        var data = Data()
        data.append(Data("\(method) \(target) \(version)\r\n".utf8))
        for (name, value) in headers {
            let lower = name.lowercased()
            if lower == "connection" || lower == "proxy-connection" { continue }
            data.append(Data("\(name): \(value)\r\n".utf8))
        }
        data.append(Data("Connection: Upgrade\r\n".utf8))
        data.append(Data("\r\n".utf8))
        data.append(body)
        return data
    }
}

struct HTTPGatewayResponse {
    var statusCode: Int
    var headers: [(String, String)]
    var body: Data

    static func text(status: Int, body: String) -> HTTPGatewayResponse {
        let data = Data(body.utf8)
        return HTTPGatewayResponse(
            statusCode: status,
            headers: [
                ("Content-Type", "text/plain; charset=utf-8"),
                ("Content-Length", String(data.count)),
                ("Connection", "close")
            ],
            body: data
        )
    }

    static func html(status: Int, body: String, extraHeaders: [(String, String)] = []) -> HTTPGatewayResponse {
        let data = Data(body.utf8)
        return HTTPGatewayResponse(
            statusCode: status,
            headers: [
                ("Content-Type", "text/html; charset=utf-8"),
                ("Content-Length", String(data.count)),
                ("Connection", "close")
            ] + extraHeaders,
            body: data
        )
    }

    func serialized() -> Data {
        var data = Data()
        let reason = HTTPGatewayResponse.reasonPhrase(for: statusCode)
        data.append(Data("HTTP/1.1 \(statusCode) \(reason)\r\n".utf8))
        for (name, value) in headers {
            data.append(Data("\(name): \(value)\r\n".utf8))
        }
        data.append(Data("\r\n".utf8))
        data.append(body)
        return data
    }

    private static func reasonPhrase(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 413: return "Payload Too Large"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default: return "HTTP Response"
        }
    }
}

private final class OnDemandGatewayConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let service: OnDemandAppsService
    private var buffer = Data()
    private var expectedBodyLength: Int?
    private var upstreamConnection: NWConnection?
    private var isClosed = false
    private var selfRetain: OnDemandGatewayConnection?

    init(connection: NWConnection, service: OnDemandAppsService) {
        self.connection = connection
        self.service = service
    }

    func start(on queue: DispatchQueue) {
        selfRetain = self
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.cancel()
            } else if case .cancelled = state {
                self?.cancel()
            }
        }
        connection.start(queue: queue)
        receiveNextChunk()
    }

    private func receiveNextChunk() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.send(.text(status: 502, body: "Gateway receive error: \(error.localizedDescription)"))
                return
            }
            if let data, !data.isEmpty {
                self.buffer.append(data)
            }

            if let parsed = self.tryParseRequest() {
                Task {
                    if parsed.request.isWebSocketUpgrade {
                        let prep = await self.service.prepareWebSocketTunnel(for: parsed.request)
                        switch prep {
                        case let .failure(response):
                            self.send(response)
                        case let .ready(host, port):
                            self.startWebSocketTunnel(
                                request: parsed.request,
                                targetHost: host,
                                targetPort: port,
                                clientRemainder: parsed.remainder
                            )
                        }
                    } else {
                        let response = await self.service.handleProxyRequest(parsed.request)
                        self.send(response)
                    }
                }
                return
            }

            if isComplete {
                self.send(.text(status: 400, body: "Incomplete HTTP request"))
                return
            }

            self.receiveNextChunk()
        }
    }

    private func tryParseRequest() -> ParsedGatewayRequest? {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: delimiter) else { return nil }
        let headerData = buffer.subdata(in: 0..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }

        let headers = lines.dropFirst().compactMap { line -> (String, String)? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return (name, value)
        }

        if expectedBodyLength == nil {
            expectedBodyLength = headers
                .first { $0.0.caseInsensitiveCompare("Content-Length") == .orderedSame }
                .flatMap { Int($0.1) } ?? 0
        }
        let bodyLength = expectedBodyLength ?? 0
        let bodyStart = headerRange.upperBound
        let availableBodyLength = buffer.count - bodyStart
        guard availableBodyLength >= bodyLength else { return nil }

        if headers.contains(where: { $0.0.caseInsensitiveCompare("Transfer-Encoding") == .orderedSame && $0.1.lowercased().contains("chunked") }) {
            let bodyStart = headerRange.upperBound
            let consumedLength = bodyStart
            let remainder = buffer.count > consumedLength ? buffer.subdata(in: consumedLength..<buffer.count) : Data()
            return ParsedGatewayRequest(
                request: HTTPGatewayRequest(
                    method: String(parts[0]),
                    target: String(parts[1]),
                    version: String(parts[2]),
                    headers: headers,
                    body: Data()
                ),
                remainder: remainder
            )
        }

        let body = buffer.subdata(in: bodyStart..<(bodyStart + bodyLength))
        let consumedLength = bodyStart + bodyLength
        let remainder = buffer.count > consumedLength ? buffer.subdata(in: consumedLength..<buffer.count) : Data()
        return ParsedGatewayRequest(
            request: HTTPGatewayRequest(
                method: String(parts[0]),
                target: String(parts[1]),
                version: String(parts[2]),
                headers: headers,
                body: body
            ),
            remainder: remainder
        )
    }

    private func startWebSocketTunnel(
        request: HTTPGatewayRequest,
        targetHost: String,
        targetPort: Int,
        clientRemainder: Data
    ) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(targetPort)) else {
            send(.text(status: 500, body: "Invalid websocket target port"))
            return
        }

        let upstream = NWConnection(host: NWEndpoint.Host(targetHost), port: port, using: .tcp)
        upstreamConnection = upstream
        upstream.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                var initialData = request.serializedForForwarding()
                if !clientRemainder.isEmpty {
                    initialData.append(clientRemainder)
                }
                upstream.send(content: initialData, completion: .contentProcessed { [weak self] error in
                    if let error {
                        AppLogService.logError("WebSocket upstream initial send failed: \(error.localizedDescription)")
                        self?.send(.text(status: 502, body: "WebSocket upstream send failed"))
                        return
                    }
                    self?.startTunnelRelay(client: self?.connection, upstream: upstream)
                })
            case let .failed(error):
                AppLogService.logError("WebSocket upstream connection failed: \(error.localizedDescription)")
                self.send(.text(status: 502, body: "WebSocket upstream connect failed: \(error.localizedDescription)"))
            case .cancelled:
                self.closeTunnel()
            default:
                break
            }
        }
        upstream.start(queue: .global(qos: .userInitiated))
    }

    private func startTunnelRelay(client: NWConnection?, upstream: NWConnection) {
        guard let client else { return }
        AppLogService.logEvent("WebSocket tunnel established")
        relay(from: client, to: upstream, directionLabel: "client->upstream")
        relay(from: upstream, to: client, directionLabel: "upstream->client")
    }

    private func relay(from source: NWConnection, to destination: NWConnection, directionLabel: String) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                AppLogService.logError("WebSocket relay \(directionLabel) failed: \(error.localizedDescription)")
                self.closeTunnel()
                return
            }
            if let data, !data.isEmpty {
                destination.send(content: data, completion: .contentProcessed { [weak self] sendError in
                    if let sendError {
                        AppLogService.logError("WebSocket relay send \(directionLabel) failed: \(sendError.localizedDescription)")
                        self?.closeTunnel()
                        return
                    }
                    self?.relay(from: source, to: destination, directionLabel: directionLabel)
                })
                return
            }
            if isComplete {
                self.closeTunnel()
                return
            }
            self.relay(from: source, to: destination, directionLabel: directionLabel)
        }
    }

    private func send(_ response: HTTPGatewayResponse) {
        guard !isClosed else { return }
        let data = response.serialized()
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.cancel()
        })
    }

    private func cancel() {
        closeTunnel()
    }

    private func closeTunnel() {
        guard !isClosed else { return }
        isClosed = true
        upstreamConnection?.cancel()
        connection.cancel()
        selfRetain = nil
    }
}

private struct ParsedGatewayRequest {
    var request: HTTPGatewayRequest
    var remainder: Data
}

private enum PreparedAppResult {
    case ready(OnDemandAppDraft)
    case waiting(HTTPGatewayResponse)
    case failure(HTTPGatewayResponse)
}

enum WebSocketTunnelPreparationResult {
    case ready(host: String, port: Int)
    case failure(HTTPGatewayResponse)
}
