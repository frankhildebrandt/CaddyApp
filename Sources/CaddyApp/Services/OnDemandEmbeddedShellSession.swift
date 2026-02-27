import Foundation

@MainActor
final class OnDemandEmbeddedShellSession: ObservableObject {
    @Published private(set) var output: String = ""
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var statusMessage: String = ""

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var currentAppID: UUID?

    func restart(for app: OnDemandAppDraft) {
        stop()
        start(for: app)
    }

    func start(for app: OnDemandAppDraft) {
        let unit = app.unitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else {
            statusMessage = "Container/Pod Name fehlt."
            return
        }

        isStarting = true
        statusMessage = "Shell wird gestartet..."
        output = ""
        currentAppID = app.id

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", makeShellCommand(for: app, unitName: unit)]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.appendOutput(text)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.appendOutput(text)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRunning = false
                self.isStarting = false
                self.statusMessage = "Shell beendet (Exit \(terminatedProcess.terminationStatus))."
                self.cleanupReadabilityHandlers()
            }
        }

        do {
            try process.run()
            self.process = process
            self.stdinPipe = stdinPipe
            self.stdoutPipe = stdoutPipe
            self.stderrPipe = stderrPipe
            isRunning = true
            isStarting = false
            statusMessage = "Shell aktiv in der App."
            appendOutput("# Verbunden mit \(app.runtime.rawValue) \(app.unitKind.rawValue):\(unit)\n")
            send("export PS1='caddyapp-shell> '")
        } catch {
            isRunning = false
            isStarting = false
            statusMessage = "Shell-Start fehlgeschlagen."
            appendOutput("Shell konnte nicht gestartet werden: \(error.localizedDescription)\n")
            cleanupReadabilityHandlers()
        }
    }

    func send(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let stdinPipe else {
            appendOutput("Shell ist nicht aktiv.\n")
            return
        }

        appendOutput("\n$ \(trimmed)\n")
        let payload = Data((trimmed + "\n").utf8)
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: payload)
        } catch {
            appendOutput("Senden fehlgeschlagen: \(error.localizedDescription)\n")
        }
    }

    func stop() {
        guard let process else { return }
        cleanupReadabilityHandlers()
        process.terminate()
        self.process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
        isStarting = false
        statusMessage = "Shell gestoppt."
    }

    private func makeShellCommand(for app: OnDemandAppDraft, unitName: String) -> String {
        let unit = shellEscape(unitName)
        let runtime = app.runtime.rawValue
        switch app.unitKind {
        case .container:
            return """
            \(runtime) exec -i \(unit) /bin/sh || \
            \(runtime) exec -i \(unit) sh || \
            \(runtime) exec -i \(unit) /bin/bash || \
            \(runtime) exec -i \(unit) bash
            """
        case .pod:
            return """
            \(runtime) pod exec -i \(unit) /bin/sh || \
            \(runtime) pod exec -i \(unit) sh || \
            \(runtime) pod exec -i \(unit) /bin/bash || \
            \(runtime) pod exec -i \(unit) bash
            """
        }
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appendOutput(_ text: String) {
        output += text
        if output.count > 200_000 {
            output = String(output.suffix(200_000))
        }
    }

    private func cleanupReadabilityHandlers() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
    }
}
