import Foundation

struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

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
