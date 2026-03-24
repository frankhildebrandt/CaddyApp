import Foundation

enum AppLogService {
    struct LogChunk {
        let lines: [String]
        let startOffset: UInt64
        let endOffset: UInt64
        let fileSize: UInt64
    }

    enum IncrementalReadResult {
        case appended(LogChunk)
        case reset(LogChunk)
        case noChange(fileSize: UInt64)
    }

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

    static func readTailChunk(maxBytes: Int = 120_000) -> LogChunk {
        queue.sync { readTailChunkLocked(maxBytes: maxBytes) }
    }

    static func readOlderChunk(before offset: UInt64, maxBytes: Int = 80_000) -> LogChunk? {
        queue.sync {
            guard offset > 0 else { return nil }

            let fileSize = currentFileSize()
            let startOffset = offset > UInt64(maxBytes) ? offset - UInt64(maxBytes) : 0
            let byteCount = Int(offset - startOffset)
            guard byteCount > 0 else { return nil }

            let data = readData(startOffset: startOffset, byteCount: byteCount)
            let normalized = normalizeChunk(data, startOffset: startOffset, endOffset: offset, dropLeadingPartialLine: startOffset > 0)
            return LogChunk(
                lines: splitLines(normalized.text),
                startOffset: normalized.startOffset,
                endOffset: offset,
                fileSize: fileSize
            )
        }
    }

    static func readAppendedChunk(after offset: UInt64, maxBytes: Int = 80_000) -> IncrementalReadResult {
        queue.sync {
            let fileSize = currentFileSize()
            if fileSize < offset {
                return .reset(readTailChunkLocked(maxBytes: maxBytes))
            }
            guard fileSize > offset else {
                return .noChange(fileSize: fileSize)
            }

            let startOffset: UInt64
            if fileSize - offset > UInt64(maxBytes) {
                startOffset = fileSize - UInt64(maxBytes)
            } else {
                startOffset = offset
            }

            let data = readData(startOffset: startOffset, byteCount: Int(fileSize - startOffset))
            let normalized = normalizeChunk(
                data,
                startOffset: startOffset,
                endOffset: fileSize,
                dropLeadingPartialLine: startOffset > 0
            )
            let chunk = LogChunk(
                lines: splitLines(normalized.text),
                startOffset: normalized.startOffset,
                endOffset: fileSize,
                fileSize: fileSize
            )

            if startOffset > offset {
                return .reset(chunk)
            }
            return .appended(chunk)
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

    private static func currentFileSize() -> UInt64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: AppPaths.appLogFile.path)
        return attributes?[.size] as? UInt64 ?? 0
    }

    private static func readTailChunkLocked(maxBytes: Int) -> LogChunk {
        let fileSize = currentFileSize()
        guard fileSize > 0 else {
            return LogChunk(lines: [], startOffset: 0, endOffset: 0, fileSize: 0)
        }

        let startOffset = fileSize > UInt64(maxBytes) ? fileSize - UInt64(maxBytes) : 0
        let data = readData(startOffset: startOffset, byteCount: Int(fileSize - startOffset))
        let normalized = normalizeChunk(data, startOffset: startOffset, endOffset: fileSize, dropLeadingPartialLine: startOffset > 0)
        return LogChunk(
            lines: splitLines(normalized.text),
            startOffset: normalized.startOffset,
            endOffset: fileSize,
            fileSize: fileSize
        )
    }

    private static func readData(startOffset: UInt64, byteCount: Int) -> Data {
        guard byteCount > 0 else { return Data() }
        do {
            let handle = try FileHandle(forReadingFrom: AppPaths.appLogFile)
            defer { try? handle.close() }
            try handle.seek(toOffset: startOffset)
            return try handle.read(upToCount: byteCount) ?? Data()
        } catch {
            return Data()
        }
    }

    private static func normalizeChunk(
        _ data: Data,
        startOffset: UInt64,
        endOffset: UInt64,
        dropLeadingPartialLine: Bool
    ) -> (text: String, startOffset: UInt64, endOffset: UInt64) {
        guard !data.isEmpty else {
            return ("", startOffset, endOffset)
        }

        var text = String(decoding: data, as: UTF8.self)
        var adjustedStartOffset = startOffset

        if dropLeadingPartialLine, let newlineIndex = text.firstIndex(of: "\n") {
            let upperBound = text.index(after: newlineIndex)
            let removedPrefix = text[..<upperBound]
            adjustedStartOffset += UInt64(removedPrefix.utf8.count)
            text.removeSubrange(..<upperBound)
        }

        return (text, adjustedStartOffset, endOffset)
    }

    private static func splitLines(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if text.hasSuffix("\n"), lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    private static func makeTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
