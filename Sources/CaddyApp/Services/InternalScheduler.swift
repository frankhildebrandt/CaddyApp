import Foundation

actor InternalScheduler {
    enum Policy {
        case replace
        case keepExisting
    }

    private var jobs: [String: Task<Void, Never>] = [:]

    func scheduleRepeating(
        id: String,
        intervalNanoseconds: UInt64,
        initialDelayNanoseconds: UInt64 = 0,
        policy: Policy = .replace,
        operation: @escaping @Sendable () async -> Void
    ) {
        if policy == .keepExisting, jobs[id] != nil {
            return
        }

        jobs[id]?.cancel()
        jobs[id] = Task {
            if initialDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: initialDelayNanoseconds)
            }
            while !Task.isCancelled {
                await operation()
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
        }
    }

    func scheduleDebounced(
        id: String,
        delayNanoseconds: UInt64,
        operation: @escaping @Sendable () async -> Void
    ) {
        jobs[id]?.cancel()
        jobs[id] = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await operation()
            jobs[id] = nil
        }
    }

    func cancel(id: String) {
        jobs[id]?.cancel()
        jobs[id] = nil
    }

    func cancelAll() {
        for task in jobs.values {
            task.cancel()
        }
        jobs.removeAll()
    }
}
