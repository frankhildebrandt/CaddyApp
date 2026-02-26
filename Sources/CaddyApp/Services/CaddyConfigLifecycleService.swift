import Foundation

struct CaddyConfigLifecycleService {
    private let shell = ShellCommandRunner()
    private let privilegedRunner = PrivilegedCommandRunner()
    private let defaultAdminEndpoint = "localhost:2019"
    private let fileManager = FileManager.default

    private struct ConfigFileBackup {
        let existed: Bool
        let contents: Data?
    }

    func runtimeStatus() -> CaddyRuntimeStatus {
        let result = shell.runShell("curl -fsS http://\(defaultAdminEndpoint)/config/ >/dev/null 2>&1")
        return CaddyRuntimeStatus(isRunning: result.isSuccess, adminEndpoint: defaultAdminEndpoint)
    }

    func write(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let fileURL = URL(fileURLWithPath: preview.caddyfilePath)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try preview.generatedCaddyfile.write(to: fileURL, atomically: true, encoding: .utf8)
            return ConfigOperationResult(
                kind: .write,
                succeeded: true,
                message: "Caddyfile written to \(preview.caddyfilePath)",
                output: "",
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

        let privilegedStart = privilegedRunner.runWithAdministratorPrivileges(
            privilegedShellCommand("caddy start --config '\(escape(preview.caddyfilePath))' --adapter caddyfile"),
            prompt: "CaddyApp needs administrator permission to start Caddy."
        )
        let privilegedOutput = combinedOutput(from: privilegedStart)
        if privilegedStart.isSuccess {
            return ConfigOperationResult(
                kind: .start,
                succeeded: true,
                message: "Caddy start succeeded via macOS administrator dialog",
                output: privilegedOutput,
                performedAt: Date()
            )
        }

        if isAuthorizationCancelled(privilegedOutput) {
            return ConfigOperationResult(
                kind: .start,
                succeeded: false,
                message: "Caddy start cancelled in macOS administrator dialog",
                output: privilegedOutput,
                performedAt: Date()
            )
        }

        let startResult = shell.runShell("caddy start --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        let startOutput = combinedOutput(from: startResult)
        return ConfigOperationResult(
            kind: .start,
            succeeded: startResult.isSuccess,
            message: startResult.isSuccess
                ? "Caddy start succeeded (after macOS administrator dialog attempt)"
                : "Caddy start failed (macOS administrator dialog + direct start)",
            output: [privilegedOutput, startOutput].filter { !$0.isEmpty }.joined(separator: "\n\n--- direct fallback ---\n\n"),
            performedAt: Date()
        )
    }

    func stop() -> ConfigOperationResult {
        let stopResult = shell.runShell("caddy stop")
        if stopResult.isSuccess {
            return mapResult(kind: .stop, baseMessage: "Caddy stop", result: stopResult)
        }

        let stopOutput = combinedOutput(from: stopResult)
        guard shouldRetryWithPrivileges(stopOutput) else {
            return mapResult(kind: .stop, baseMessage: "Caddy stop", result: stopResult)
        }

        let privilegedStop = privilegedRunner.runWithAdministratorPrivileges(
            privilegedShellCommand("caddy stop"),
            prompt: "CaddyApp needs administrator permission to stop Caddy."
        )
        let privilegedOutput = combinedOutput(from: privilegedStop)
        return ConfigOperationResult(
            kind: .stop,
            succeeded: privilegedStop.isSuccess,
            message: privilegedStop.isSuccess
                ? "Caddy stop succeeded via macOS administrator dialog"
                : "Caddy stop failed (including privileged retry)",
            output: [stopOutput, privilegedOutput].filter { !$0.isEmpty }.joined(separator: "\n\n--- privileged retry ---\n\n"),
            performedAt: Date()
        )
    }

    private func performReloadCommand(preview: CaddyConfigPreview) -> ConfigOperationResult {
        let reloadResult = shell.runShell("caddy reload --config '\(escape(preview.caddyfilePath))' --adapter caddyfile")
        if reloadResult.isSuccess {
            return mapResult(kind: .reload, baseMessage: "Caddy reload", result: reloadResult)
        }

        let reloadOutput = combinedOutput(from: reloadResult)
        if shouldRetryWithPrivileges(reloadOutput) {
            let privilegedReload = privilegedRunner.runWithAdministratorPrivileges(
                privilegedShellCommand("caddy reload --config '\(escape(preview.caddyfilePath))' --adapter caddyfile"),
                prompt: "CaddyApp needs administrator permission to reload Caddy."
            )
            let privilegedOutput = combinedOutput(from: privilegedReload)
            return ConfigOperationResult(
                kind: .reload,
                succeeded: privilegedReload.isSuccess,
                message: privilegedReload.isSuccess
                    ? "Caddy reload succeeded via macOS administrator dialog"
                    : "Caddy reload failed (including privileged retry)",
                output: [reloadOutput, privilegedOutput].filter { !$0.isEmpty }.joined(separator: "\n\n--- privileged retry ---\n\n"),
                performedAt: Date()
            )
        }

        if shouldFallbackToStart(reloadOutput) {
            let privilegedStart = privilegedRunner.runWithAdministratorPrivileges(
                privilegedShellCommand("caddy start --config '\(escape(preview.caddyfilePath))' --adapter caddyfile"),
                prompt: "CaddyApp needs administrator permission to start Caddy."
            )
            let privilegedStartOutput = combinedOutput(from: privilegedStart)
            if privilegedStart.isSuccess {
                return ConfigOperationResult(
                    kind: .reload,
                    succeeded: true,
                    message: "Caddy was not running; started a new instance via macOS administrator dialog",
                    output: [reloadOutput, privilegedStartOutput]
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n--- fallback start ---\n\n"),
                    performedAt: Date()
                )
            }
            return ConfigOperationResult(
                kind: .reload,
                succeeded: false,
                message: "Caddy reload failed and fallback start via macOS administrator dialog also failed",
                output: [reloadOutput, privilegedStartOutput].filter { !$0.isEmpty }.joined(separator: "\n\n--- fallback start ---\n\n"),
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

    private func shouldRetryWithPrivileges(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return lowered.contains("permission denied")
            || lowered.contains("operation not permitted")
            || lowered.contains("listen tcp")
            || lowered.contains("bind:")
            || lowered.contains("password")
            || lowered.contains("sudo")
    }

    private func isAuthorizationCancelled(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return lowered.contains("user canceled")
            || lowered.contains("applescript error -128")
            || lowered.contains("error -128")
    }

    private func privilegedShellCommand(_ command: String) -> String {
        let managedBin = AppPaths.managedBinDirectory.path.replacingOccurrences(of: "'", with: "'\\''")
        return "export PATH='\(managedBin)':$PATH; \(command)"
    }

    private func escape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}
