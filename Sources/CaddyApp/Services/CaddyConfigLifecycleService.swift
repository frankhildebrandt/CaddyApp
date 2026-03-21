import Foundation

struct CaddyConfigLifecycleService: @unchecked Sendable {
    private let shell = ShellCommandRunner()
    private let defaultAdminEndpoint = "localhost:2019"
    private let fileManager = FileManager.default
    private static let runtimeStatusTimeout: TimeInterval = 2

    private struct ConfigFileBackup {
        let existed: Bool
        let contents: Data?
    }

    func runtimeStatus() -> CaddyRuntimeStatus {
        let result = shell.runShell(
            "curl --connect-timeout 1 --max-time 2 -fsS http://\(defaultAdminEndpoint)/config/ >/dev/null 2>&1",
            timeout: Self.runtimeStatusTimeout
        )
        return CaddyRuntimeStatus(isRunning: result.isSuccess, adminEndpoint: defaultAdminEndpoint)
    }

    func write(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let fileURL = URL(fileURLWithPath: preview.caddyfilePath)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try preview.generatedCaddyfile.write(to: fileURL, atomically: true, encoding: .utf8)
            let formatResult = formatCaddyfile(at: preview.caddyfilePath)
            if !formatResult.isSuccess {
                AppLogService.logError("caddy fmt failed for \(preview.caddyfilePath): \(combinedOutput(from: formatResult))")
            }
            let formatOutput = combinedOutput(from: formatResult)
            let output = formatOutput.isEmpty ? "" : "caddy fmt output:\n\(formatOutput)"
            return ConfigOperationResult(
                kind: .write,
                succeeded: true,
                message: "Caddyfile written to \(preview.caddyfilePath)",
                output: output,
                performedAt: Date()
            )
        } catch {
            return ConfigOperationResult(
                kind: .write,
                succeeded: false,
                message: "Failed to write Caddyfile: \(error.localizedDescription)",
                output: "",
                performedAt: Date()
            )
        }
    }

    func validate(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let writeResult = write(preview: preview)
        guard writeResult.succeeded else {
            return ConfigOperationResult(
                kind: .validate,
                succeeded: false,
                message: "Caddy validate aborted: could not write preview config first",
                output: writeResult.message + (writeResult.output.isEmpty ? "" : "\n" + writeResult.output),
                performedAt: Date()
            )
        }

        let result = shell.runShell("caddy validate --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        return mapResult(kind: .validate, baseMessage: "Caddy validate", result: result)
    }

    func reload(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let fileURL = URL(fileURLWithPath: preview.caddyfilePath)
        let backup: ConfigFileBackup
        do {
            backup = try createBackup(for: fileURL)
        } catch {
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "Caddy reload aborted: could not create rollback backup",
                output: error.localizedDescription,
                performedAt: Date()
            )
        }

        let writeResult = write(preview: preview)
        guard writeResult.succeeded else {
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "Caddy reload aborted: could not write preview config first",
                output: writeResult.message + (writeResult.output.isEmpty ? "" : "\n" + writeResult.output),
                performedAt: Date()
            )
        }

        let validateResult = shell.runShell("caddy validate --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        if !validateResult.isSuccess {
            return rollbackAfterFailedReload(
                preview: preview,
                backup: backup,
                failureResult: mapResult(kind: .reload, baseMessage: "Caddy validate before reload", result: validateResult)
            )
        }

        let reloadResult = performReloadCommand(preview: preview)
        guard reloadResult.succeeded else {
            return rollbackAfterFailedReload(preview: preview, backup: backup, failureResult: reloadResult)
        }

        return reloadResult
    }

    func start(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let writeResult = write(preview: preview)
        guard writeResult.succeeded else {
            return ConfigOperationResult(
                kind: .start,
                succeeded: false,
                message: "Caddy start aborted: could not write preview config first",
                output: writeResult.message + (writeResult.output.isEmpty ? "" : "\n" + writeResult.output),
                performedAt: Date()
            )
        }

        let startResult = shell.runShell("caddy start --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        return mapResult(kind: .start, baseMessage: "Caddy start", result: startResult)
    }

    func stop() -> ConfigOperationResult {
        let stopResult = shell.runShell("caddy stop")
        return mapResult(kind: .stop, baseMessage: "Caddy stop", result: stopResult)
    }

    func writeAsync(preview: CaddyConfigPreview) async -> ConfigOperationResult {
        let service = self
        return await Task.detached(priority: .userInitiated) {
            service.write(preview: preview)
        }.value
    }

    func validateAsync(preview: CaddyConfigPreview) async -> ConfigOperationResult {
        let service = self
        return await Task.detached(priority: .userInitiated) {
            service.validate(preview: preview)
        }.value
    }

    func reloadAsync(preview: CaddyConfigPreview) async -> ConfigOperationResult {
        let service = self
        return await Task.detached(priority: .userInitiated) {
            service.reload(preview: preview)
        }.value
    }

    func startAsync(preview: CaddyConfigPreview) async -> ConfigOperationResult {
        let service = self
        return await Task.detached(priority: .userInitiated) {
            service.start(preview: preview)
        }.value
    }

    func stopAsync() async -> ConfigOperationResult {
        let service = self
        return await Task.detached(priority: .userInitiated) {
            service.stop()
        }.value
    }

    private func performReloadCommand(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let reloadResult = shell.runShell("caddy reload --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        if reloadResult.isSuccess {
            return mapResult(kind: .reload, baseMessage: "Caddy reload", result: reloadResult)
        }

        let reloadOutput = combinedOutput(from: reloadResult)
        if shouldFallbackToStart(reloadOutput) {
            let startResult = shell.runShell("caddy start --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
            let startOutput = combinedOutput(from: startResult)
            if startResult.isSuccess {
                return ConfigOperationResult(
                    kind: .reload,
                    succeeded: true,
                    message: "Caddy was not running; started a new instance",
                    output: [reloadOutput, startOutput]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n--- fallback start ---\n\n"),
                    performedAt: Date()
                )
            }
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "Caddy reload failed and fallback start also failed",
                output: [reloadOutput, startOutput].filter { !$0.isEmpty }.joined(separator: "\n\n--- fallback start ---\n\n"),
                performedAt: Date()
            )
        }

        return mapResult(kind: .reload, baseMessage: "Caddy reload", result: reloadResult)
    }

    private func rollbackAfterFailedReload(
        preview: CaddyConfigPreview,
        backup: ConfigFileBackup,
        failureResult: ConfigOperationResult
    ) -> ConfigOperationResult {
        let fileURL = URL(fileURLWithPath: preview.caddyfilePath)

        do {
            let rollbackMessage = try restoreBackup(backup, to: fileURL)
            let output = [failureResult.output, rollbackMessage]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n--- rollback ---\n\n")
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "\(failureResult.message); previous config restored",
                output: output,
                performedAt: Date()
            )
        } catch {
            let output = [failureResult.output, "Rollback failed: \(error.localizedDescription)"]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n--- rollback ---\n\n")
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "\(failureResult.message); rollback failed",
                output: output,
                performedAt: Date()
            )
        }
    }

    private func createBackup(for fileURL: URL) throws -> ConfigFileBackup {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ConfigFileBackup(existed: false, contents: nil)
        }
        let data = try Data(contentsOf: fileURL)
        return ConfigFileBackup(existed: true, contents: data)
    }

    private func restoreBackup(_ backup: ConfigFileBackup, to fileURL: URL) throws -> String {
        if backup.existed, let contents = backup.contents {
            try contents.write(to: fileURL, options: .atomic)
            return "Restored previous Caddyfile at \(fileURL.path)"
        }

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            return "Removed newly written Caddyfile at \(fileURL.path) (no previous file to restore)"
        }

        return "No previous Caddyfile existed; nothing to restore"
    }

    private func mapResult(kind: ConfigOperationKind, baseMessage: String, result: CommandResult) -> ConfigOperationResult {
        let combined = combinedOutput(from: result)

        return ConfigOperationResult(
            kind: kind,
            succeeded: result.isSuccess,
            message: result.isSuccess ? "\(baseMessage) succeeded" : "\(baseMessage) failed (exit \(result.exitCode))",
            output: combined,
            performedAt: Date()
        )
    }

    private func combinedOutput(from result: CommandResult) -> String {
        [result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func shouldFallbackToStart(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return lowered.contains("connection refused")
            || lowered.contains("failed to connect to admin endpoint")
            || lowered.contains("sending configuration to instance")
    }

    private func formatCaddyfile(at path: String) -> CommandResult {
        shell.runShell("caddy fmt --overwrite '\(escape(path))'")
    }

    private func escape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}
