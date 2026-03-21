import Foundation

final class ShellCommandBackoffStore: @unchecked Sendable {
    static let shared = ShellCommandBackoffStore()

    private struct State {
        var label: String
        var failureCount: Int = 0
        var nextRetryAt: Date?
        var lastResult: CommandResult?
        var lastErrorMessage: String = ""
    }

    private let lock = NSLock()
    private var states: [String: State] = [:]

    func run(
        key: String,
        label: String,
        commandDescription: String,
        operation: () -> CommandResult
    ) -> CommandResult {
        if let cached = cachedResultIfBackingOff(for: key) {
            return cached
        }

        let rawResult = operation()
        let now = Date()

        if rawResult.isSuccess {
            let recoveryCount = lock.withLock {
                let previous = states[key]?.failureCount ?? 0
                states.removeValue(forKey: key)
                return previous
            }
            if recoveryCount > 0 {
                AppLogService.logEvent("CLI recovered after \(recoveryCount) failure(s): [\(label)] \(commandDescription)")
            }
            return rawResult
        }

        let errorMessage = summarizedError(from: rawResult, fallback: "Command failed")
        let annotatedResult = lock.withLock { () -> CommandResult in
            var state = states[key] ?? State(label: label)
            state.label = label
            state.failureCount += 1
            state.lastErrorMessage = errorMessage
            let delaySeconds = Self.retryDelaySeconds(forFailureCount: state.failureCount)
            state.nextRetryAt = now.addingTimeInterval(delaySeconds)
            state.lastResult = CommandResult(
                exitCode: rawResult.exitCode,
                stdout: rawResult.stdout,
                stderr: rawResult.stderr,
                didUseBackoff: false,
                nextRetryAt: state.nextRetryAt,
                consecutiveFailureCount: state.failureCount
            )
            states[key] = state
            return CommandResult(
                exitCode: rawResult.exitCode,
                stdout: rawResult.stdout,
                stderr: rawResult.stderr,
                didUseBackoff: false,
                nextRetryAt: state.nextRetryAt,
                consecutiveFailureCount: state.failureCount
            )
        }

        let retryText: String
        if let nextRetryAt = annotatedResult.nextRetryAt {
            retryText = "next retry in \(Int(max(nextRetryAt.timeIntervalSince(now), 1)))s"
        } else {
            retryText = "retry scheduled"
        }
        AppLogService.logError("CLI backoff: [\(label)] \(commandDescription) failed (\(retryText))")
        return annotatedResult
    }

    func dashboardIssues() -> [ShellCommandIssue] {
        lock.withLock {
            let grouped = Dictionary(grouping: states.values.filter { $0.failureCount > 0 }, by: \.label)
            return grouped.compactMap { label, group in
                guard let dominant = group.max(by: { lhs, rhs in
                    if lhs.failureCount != rhs.failureCount {
                        return lhs.failureCount < rhs.failureCount
                    }
                    return (lhs.nextRetryAt ?? .distantPast) < (rhs.nextRetryAt ?? .distantPast)
                }) else {
                    return nil
                }
                return ShellCommandIssue(
                    label: label,
                    failureCount: dominant.failureCount,
                    nextRetryAt: dominant.nextRetryAt,
                    message: dominant.lastErrorMessage
                )
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        }
    }

    func reset() {
        lock.withLock {
            states.removeAll()
        }
    }

    static func retryDelaySeconds(forFailureCount failureCount: Int) -> TimeInterval {
        let normalizedCount = max(failureCount, 1)
        if normalizedCount == 1 {
            return 1
        }
        return min(TimeInterval(1 << (normalizedCount - 1)), 30)
    }

    private func cachedResultIfBackingOff(for key: String) -> CommandResult? {
        lock.withLock {
            guard let state = states[key],
                  state.failureCount > 0,
                  let nextRetryAt = state.nextRetryAt,
                  Date() < nextRetryAt,
                  let lastResult = state.lastResult else {
                return nil
            }
            return CommandResult(
                exitCode: lastResult.exitCode,
                stdout: lastResult.stdout,
                stderr: lastResult.stderr,
                didUseBackoff: true,
                nextRetryAt: nextRetryAt,
                consecutiveFailureCount: state.failureCount
            )
        }
    }

    private func summarizedError(from result: CommandResult, fallback: String) -> String {
        let text = [result.stderr, result.stdout]
            .joined(separator: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return text ?? fallback
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
