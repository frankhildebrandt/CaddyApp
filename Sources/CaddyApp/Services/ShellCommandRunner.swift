import Foundation

struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let didUseBackoff: Bool
    let nextRetryAt: Date?
    let consecutiveFailureCount: Int

    init(
        exitCode: Int32,
        stdout: String,
        stderr: String,
        didUseBackoff: Bool = false,
        nextRetryAt: Date? = nil,
        consecutiveFailureCount: Int = 0
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.didUseBackoff = didUseBackoff
        self.nextRetryAt = nextRetryAt
        self.consecutiveFailureCount = consecutiveFailureCount
    }

    var isSuccess: Bool { exitCode == 0 }
}

struct ShellCommandRunner: Sendable {
    @discardableResult
    func run(_ launchPath: String, arguments: [String] = []) -> CommandResult {
        let renderedCommand = ([launchPath] + arguments.map(shellEscape)).joined(separator: " ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLogService.logError("CLI spawn failed: \(renderedCommand) :: \(error.localizedDescription)")
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        let result = CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
        if !result.isSuccess {
            let combinedOutput = [stdout, stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let outputSnippet = combinedOutput.isEmpty ? "(no output)" : String(combinedOutput.prefix(2000))
            AppLogService.logError("CLI exit=\(result.exitCode): \(renderedCommand)\n\(outputSnippet)")
        }
        return result
    }

    func runShell(_ command: String) -> CommandResult {
        let managedBin = AppPaths.managedBinDirectory.path.replacingOccurrences(of: "'", with: "'\\''")
        let wrappedCommand = "export PATH='\(managedBin)':$PATH; \(command)"
        return run("/bin/zsh", arguments: ["-lc", wrappedCommand])
    }

    func runWithBackoff(
        _ launchPath: String,
        arguments: [String] = [],
        key: String,
        label: String
    ) -> CommandResult {
        let renderedCommand = ([launchPath] + arguments.map(shellEscape)).joined(separator: " ")
        return ShellCommandBackoffStore.shared.run(
            key: key,
            label: label,
            commandDescription: renderedCommand
        ) {
            run(launchPath, arguments: arguments)
        }
    }

    func runShellWithBackoff(_ command: String, key: String, label: String) -> CommandResult {
        ShellCommandBackoffStore.shared.run(
            key: key,
            label: label,
            commandDescription: command
        ) {
            runShell(command)
        }
    }

    func runAsync(_ launchPath: String, arguments: [String] = []) async -> CommandResult {
        await Task.detached(priority: .userInitiated) {
            run(launchPath, arguments: arguments)
        }.value
    }

    func runShellAsync(_ command: String) async -> CommandResult {
        await Task.detached(priority: .userInitiated) {
            runShell(command)
        }.value
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
