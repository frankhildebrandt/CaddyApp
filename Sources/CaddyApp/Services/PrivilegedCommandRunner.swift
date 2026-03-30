import AppKit
import Foundation

struct PrivilegedCommandRunner:  Sendable {
    @MainActor
    func runWithAdministratorPrivileges(_ command: String, prompt: String? = nil) -> CommandResult {
        let script = appleScriptForShellCommand(command, prompt: prompt)
        return executeAppleScriptOnCurrentThread(script)
    }

    private func appleScriptForShellCommand(_ command: String, prompt: String?) -> String {
        let escapedCommand = escapeForAppleScript(command)
        if let prompt, !prompt.isEmpty {
            let escapedPrompt = escapeForAppleScript(prompt)
            return "do shell script \"\(escapedCommand)\" with administrator privileges with prompt \"\(escapedPrompt)\""
        }
        return "do shell script \"\(escapedCommand)\" with administrator privileges"
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func executeAppleScriptOnCurrentThread(_ source: String) -> CommandResult {
        guard let script = NSAppleScript(source: source) else {
            return CommandResult(exitCode: 1, stdout: "", stderr: "Failed to prepare macOS authorization dialog")
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let brief = errorInfo[NSAppleScript.errorBriefMessage] as? String
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.int32Value ?? 1

            let parts = [brief, message, "AppleScript error \(number)"]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return CommandResult(
                exitCode: 1,
                stdout: "",
                stderr: parts.joined(separator: "\n")
            )
        }

        return CommandResult(
            exitCode: 0,
            stdout: descriptor.stringValue ?? "",
            stderr: ""
        )
    }
}
