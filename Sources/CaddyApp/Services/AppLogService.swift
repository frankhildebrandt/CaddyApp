import Foundation

enum AppLogService {
    private static let queue = DispatchQueue(label: "caddyapp.logs")

    static func logEvent(_ message: String) {
        append(level: "INFO", message: message)
    }

    static func logError(_ message: String) {
        append(level: "ERROR", message: message)
    }

    static func readLog(maxBytes: Int = 200_000) -> String {
        queue.sync {
            guard let data = try? Data(contentsOf: AppPaths.appLogFile) else {
                return ""
            }
            let slicedData: Data
            if data.count > maxBytes {
                slicedData = data.suffix(maxBytes)
            } else {
                slicedData = data
            }
            return String(data: slicedData, encoding: .utf8) ?? ""
        }
    }

    static func clearLog() throws {
        try queue.sync {
            try ensureDirectoryExists()
            try Data().write(to: AppPaths.appLogFile, options: .atomic)
        }
    }

    private static func append(level: String, message: String) {
        queue.async {
            do {
                try ensureDirectoryExists()
                let timestamp = makeTimestamp(Date())
                let line = "[\(timestamp)] [\(level)] \(message)\n"
                let data = Data(line.utf8)
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: AppPaths.appLogFile.path) {
                    let handle = try FileHandle(forWritingTo: AppPaths.appLogFile)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: AppPaths.appLogFile, options: .atomic)
                }
            } catch {
                // Last-resort fallback: logging must never break app behavior.
                fputs("CaddyApp logging error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true)
    }

    private static func makeTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
