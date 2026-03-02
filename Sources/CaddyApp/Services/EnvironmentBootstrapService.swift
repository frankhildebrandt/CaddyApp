import Foundation

struct EnvironmentBootstrapService {
    private let shell = ShellCommandRunner()
    private let installService = CaddyInstallationService()
    private let fileManager = FileManager.default
    private let brewServiceConfigPath = "/opt/homebrew/etc/Caddyfile"

    func runAutoSetupIfNeeded(caddyInstall: CaddyInstallStatus, tlsStatus: TLSStatus) -> AutoSetupReport {
        var operations: [SetupOperationResult] = []

        var currentInstall = caddyInstall
        if !currentInstall.isInstalled {
            let installResult = installCaddy()
            operations.append(installResult)
            currentInstall = CaddyInstallationService().loadStatus()
        }

        let currentTLS = LocalhostTLSService().status()
        if currentInstall.isInstalled && !currentTLS.rootCertificatePresent {
            operations.append(generateLocalCARoot())
        }
        if let serviceRepair = repairMissingHomebrewCaddyfileIfNeeded() {
            operations.append(serviceRepair)
        }
        if let consolidation = consolidateCaddyInstancesIfNeeded() {
            operations.append(consolidation)
        }

        return AutoSetupReport(
            attempted: !operations.isEmpty,
            operations: operations
        )
    }

    private func installCaddy() -> SetupOperationResult {
        installService.installForBootstrap()
    }

    private func generateLocalCARoot() -> SetupOperationResult {
        let supportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CaddyApp/bootstrap", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        } catch {
            return SetupOperationResult(
                kind: .generateLocalCA,
                succeeded: false,
                message: "Failed to create bootstrap directory for CA generation",
                output: error.localizedDescription,
                performedAt: Date()
            )
        }

        let configURL = supportDir.appendingPathComponent("generate-ca.Caddyfile")
        let adminAddress = "localhost:29201"
        let siteHost = "bootstrap-ca.localhost"
        let sitePort = 29443

        let config = """
        {
            admin \(adminAddress)
        }

        \(siteHost):\(sitePort) {
            tls internal
            respond \"bootstrap\" 200
        }
        """

        do {
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            return SetupOperationResult(
                kind: .generateLocalCA,
                succeeded: false,
                message: "Failed to write temporary bootstrap Caddyfile",
                output: error.localizedDescription,
                performedAt: Date()
            )
        }

        let command = """
        caddy start --config '\(escape(configURL.path))' --adapter caddyfile && \
        sleep 1 && \
        curl -sk --resolve \(siteHost):\(sitePort):127.0.0.1 https://\(siteHost):\(sitePort)/ >/dev/null 2>&1; \
        status=$?; \
        caddy stop --admin \(adminAddress) >/dev/null 2>&1; \
        exit $status
        """

        let result = shell.runShell(command)
        let tlsStatusAfter = LocalhostTLSService().status()
        let output = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let succeeded = tlsStatusAfter.rootCertificatePresent
        let message: String
        if succeeded {
            message = "Local Caddy CA root generated automatically"
        } else {
            message = result.isSuccess
                ? "CA generation command finished but root certificate still missing"
                : "Automatic local CA generation failed"
        }

        return SetupOperationResult(
            kind: .generateLocalCA,
            succeeded: succeeded,
            message: message,
            output: output,
            performedAt: Date()
        )
    }

    private func escape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func repairMissingHomebrewCaddyfileIfNeeded() -> SetupOperationResult? {
        let brewCheck = shell.runShell("command -v brew")
        guard brewCheck.isSuccess else { return nil }

        let prefixResult = shell.runShell("brew --prefix")
        guard prefixResult.isSuccess else { return nil }
        let brewPrefix = prefixResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brewPrefix.isEmpty else { return nil }

        let brewCaddyfileURL = URL(fileURLWithPath: brewPrefix)
            .appendingPathComponent("etc", isDirectory: true)
            .appendingPathComponent("Caddyfile", isDirectory: false)
        if fileManager.fileExists(atPath: brewCaddyfileURL.path) {
            return nil
        }

        let generatedConfigURL = AppPaths.appSupportDirectory
            .appendingPathComponent("Caddyfile", isDirectory: false)
        var actions: [String] = []

        do {
            try fileManager.createDirectory(
                at: brewCaddyfileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: generatedConfigURL.path) {
                try fileManager.createSymbolicLink(
                    atPath: brewCaddyfileURL.path,
                    withDestinationPath: generatedConfigURL.path
                )
                actions.append("Created symlink \(brewCaddyfileURL.path) -> \(generatedConfigURL.path)")
            } else {
                let fallback = """
                :8080 {
                    respond "CaddyApp bootstrap config"
                }
                """
                try fallback.write(to: brewCaddyfileURL, atomically: true, encoding: .utf8)
                actions.append("Created fallback Caddyfile at \(brewCaddyfileURL.path)")
            }
        } catch {
            return SetupOperationResult(
                kind: .repairHomebrewService,
                succeeded: false,
                message: "Homebrew Caddy service repair failed while preparing Caddyfile",
                output: [actions.joined(separator: "\n"), error.localizedDescription]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n"),
                performedAt: Date()
            )
        }

        var restartAttempted = false
        var restartSucceeded = true
        let statusBefore = shell.runShell("brew services list | awk '$1==\"caddy\" {print $2}'")
            .stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !statusBefore.isEmpty, statusBefore != "none" {
            restartAttempted = true
            let restartResult = shell.runShell("brew services restart caddy")
            let restartOutput = [restartResult.stdout, restartResult.stderr]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            restartSucceeded = restartResult.isSuccess
            if !restartOutput.isEmpty {
                actions.append(restartOutput)
            }
        }

        let statusAfter = shell.runShell("brew services list | awk '$1==\"caddy\" {print $2}'")
            .stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !statusBefore.isEmpty {
            actions.append("brew services status: \(statusBefore) -> \(statusAfter.isEmpty ? "unknown" : statusAfter)")
        }

        let succeeded = fileManager.fileExists(atPath: brewCaddyfileURL.path) && (!restartAttempted || restartSucceeded)
        return SetupOperationResult(
            kind: .repairHomebrewService,
            succeeded: succeeded,
            message: succeeded
                ? "Repaired Homebrew Caddy service configuration"
                : "Prepared Homebrew Caddyfile, but service restart failed",
            output: actions.joined(separator: "\n"),
            performedAt: Date()
        )
    }

    private func consolidateCaddyInstancesIfNeeded() -> SetupOperationResult? {
        let processResult = shell.runShell("pgrep -fl 'caddy run'")
        guard processResult.isSuccess else { return nil }

        let lines = processResult.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let processes = lines.compactMap(parseCaddyProcessLine)
        guard processes.count > 1 else { return nil }

        let preferredPID = choosePreferredPID(from: processes)
        let toStop = processes.filter { $0.pid != preferredPID }

        var output: [String] = [
            "Detected multiple Caddy instances: \(processes.map { "\($0.pid)" }.joined(separator: ", "))",
            "Keeping PID \(preferredPID) and stopping \(toStop.map { "\($0.pid)" }.joined(separator: ", "))"
        ]

        var allSucceeded = true
        for process in toStop {
            let stopResult = shell.runShell("kill \(process.pid)")
            if !stopResult.isSuccess {
                allSucceeded = false
            }
            let stopOutput = [stopResult.stdout, stopResult.stderr]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            output.append("kill \(process.pid): \(stopResult.isSuccess ? "ok" : "failed")")
            if !stopOutput.isEmpty {
                output.append(stopOutput)
            }
        }

        _ = shell.runShell("sleep 1")
        let verifyResult = shell.runShell("pgrep -fl 'caddy run'")
        let remaining = verifyResult.stdout
            .split(separator: "\n")
            .map(String.init)
            .compactMap(parseCaddyProcessLine)

        if remaining.count > 1 {
            allSucceeded = false
            output.append("Remaining Caddy PIDs after consolidation: \(remaining.map { "\($0.pid)" }.joined(separator: ", "))")
        } else if let only = remaining.first {
            output.append("Remaining Caddy PID: \(only.pid)")
        } else {
            output.append("No Caddy run process remains after consolidation")
        }

        return SetupOperationResult(
            kind: .consolidateCaddyInstances,
            succeeded: allSucceeded,
            message: allSucceeded
                ? "Consolidated multiple Caddy instances to a single process"
                : "Detected multiple Caddy instances, but consolidation was not fully successful",
            output: output.joined(separator: "\n"),
            performedAt: Date()
        )
    }

    private func choosePreferredPID(from processes: [CaddyProcess]) -> Int {
        if let brewProcess = processes.first(where: { $0.command.contains("/opt/homebrew/opt/caddy/bin/caddy run") && $0.command.contains("--config \(brewServiceConfigPath)") }) {
            return brewProcess.pid
        }
        if let brewConfigProcess = processes.first(where: { $0.command.contains("--config \(brewServiceConfigPath)") }) {
            return brewConfigProcess.pid
        }
        return processes.sorted { $0.pid < $1.pid }.first?.pid ?? processes[0].pid
    }

    private func parseCaddyProcessLine(_ line: String) -> CaddyProcess? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard let pidPart = parts.first, let pid = Int(pidPart) else { return nil }
        let command = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return CaddyProcess(pid: pid, command: command)
    }

    private struct CaddyProcess {
        let pid: Int
        let command: String
    }
}
