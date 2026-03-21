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
    func run(_ launchPath: String, arguments: [String] = [], timeout: TimeInterval? = nil) -> CommandResult {
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
        } catch {
            AppLogService.logError("CLI spawn failed: \(renderedCommand) :: \(error.localizedDescription)")
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let didTimeout = waitForExit(of: process, timeout: timeout)

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if didTimeout {
            let timeoutNote = "Command timed out after \(formattedTimeout(timeout))s"
            let mergedStderr = stderr.isEmpty ? timeoutNote : "\(stderr)\n\(timeoutNote)"
            AppLogService.logError("CLI timeout: \(renderedCommand)")
            return CommandResult(exitCode: 124, stdout: stdout, stderr: mergedStderr)
        }

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

    func runShell(_ command: String, timeout: TimeInterval? = nil) -> CommandResult {
        let managedBin = AppPaths.managedBinDirectory.path.replacingOccurrences(of: "'", with: "'\\''")
        let wrappedCommand = "export PATH='\(managedBin)':$PATH; \(command)"
        return run("/bin/zsh", arguments: ["-lc", wrappedCommand], timeout: timeout)
    }

    func runWithBackoff(
        _ launchPath: String,
        arguments: [String] = [],
        key: String,
        label: String,
        timeout: TimeInterval? = nil
    ) -> CommandResult {
        let renderedCommand = ([launchPath] + arguments.map(shellEscape)).joined(separator: " ")
        return ShellCommandBackoffStore.shared.run(
            key: key,
            label: label,
            commandDescription: renderedCommand
        ) {
            run(launchPath, arguments: arguments, timeout: timeout)
        }
    }

    func runShellWithBackoff(_ command: String, key: String, label: String, timeout: TimeInterval? = nil) -> CommandResult {
        ShellCommandBackoffStore.shared.run(
            key: key,
            label: label,
            commandDescription: command
        ) {
            runShell(command, timeout: timeout)
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

    private func waitForExit(of process: Process, timeout: TimeInterval?) -> Bool {
        guard let timeout else {
            process.waitUntilExit()
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                let forcedKillDeadline = Date().addingTimeInterval(1)
                while process.isRunning, Date() < forcedKillDeadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    process.waitUntilExit()
                }
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()
        return false
    }

    private func formattedTimeout(_ timeout: TimeInterval?) -> String {
        guard let timeout else { return "0" }
        let rounded = (timeout * 10).rounded() / 10
        if rounded.rounded(.down) == rounded {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}
