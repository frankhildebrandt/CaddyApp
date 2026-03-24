import Foundation
import SwiftUI

@MainActor
final class LogViewportViewModel: ObservableObject {
    struct VisibleLine: Identifiable, Equatable {
        let id: Int
        let text: String
    }

    private static let initialTailBytes = 120_000
    private static let olderChunkBytes = 80_000
    private static let appendChunkBytes = 40_000
    private static let maxRetainedLines = 4_000
    private static let liveWatchIntervalNanoseconds: UInt64 = 1_000_000_000

    @Published private(set) var visibleLines: [VisibleLine] = []
    @Published private(set) var loadedLineCount = 0
    @Published private(set) var matchCount = 0
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasOlderLines = false
    @Published private(set) var contentVersion = 0
    @Published var filterQuery = ""
    @Published var liveEnabled = true

    private var loadedLines: [VisibleLine] = []
    private var startOffset: UInt64 = 0
    private var endOffset: UInt64 = 0
    private var liveWatchTask: Task<Void, Never>?
    private var firstLoadedID = 0
    private var nextAppendedID = 0

    deinit {
        liveWatchTask?.cancel()
    }

    func loadInitialTail() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let initialTailBytes = Self.initialTailBytes
        let chunk = await Task.detached(priority: .userInitiated) {
            AppLogService.readTailChunk(maxBytes: initialTailBytes)
        }.value
        applyReload(chunk)
    }

    func reloadTail() async {
        await loadInitialTail()
    }

    func clearLogs() async {
        do {
            try AppLogService.clearLog()
            AppLogService.logEvent("Log file cleared by user")
        } catch {
            return
        }
        await loadInitialTail()
    }

    func loadOlderIfNeeded() async {
        guard hasOlderLines, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        let currentStartOffset = startOffset
        let olderChunkBytes = Self.olderChunkBytes
        let chunk = await Task.detached(priority: .utility) {
            AppLogService.readOlderChunk(before: currentStartOffset, maxBytes: olderChunkBytes)
        }.value
        guard let chunk else {
            hasOlderLines = false
            return
        }

        guard !chunk.lines.isEmpty else {
            startOffset = chunk.startOffset
            hasOlderLines = chunk.startOffset > 0
            return
        }

        let prepended = makePrependedLines(chunk.lines)
        loadedLines.insert(contentsOf: prepended, at: 0)
        startOffset = chunk.startOffset
        trimRetainedLinesIfNeeded()
        hasOlderLines = startOffset > 0
        rebuildVisibleLines()
    }

    func setLiveEnabled(_ enabled: Bool) {
        liveEnabled = enabled
        if enabled {
            startLiveWatch()
        } else {
            stopLiveWatch()
        }
    }

    func startLiveWatch() {
        guard liveWatchTask == nil else { return }
        guard liveEnabled else { return }

        liveWatchTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.liveWatchIntervalNanoseconds)
                await self.pollForAppendedLines()
            }
        }
    }

    func stopLiveWatch() {
        liveWatchTask?.cancel()
        liveWatchTask = nil
    }

    func updateFilterQuery(_ query: String) {
        guard filterQuery != query else { return }
        filterQuery = query
        rebuildVisibleLines()
    }

    private func pollForAppendedLines() async {
        guard !isRefreshing, !isLoadingOlder else { return }

        let currentEndOffset = endOffset
        let appendChunkBytes = Self.appendChunkBytes
        let result = await Task.detached(priority: .utility) {
            AppLogService.readAppendedChunk(after: currentEndOffset, maxBytes: appendChunkBytes)
        }.value

        switch result {
        case .noChange:
            return
        case .reset(let chunk):
            applyReload(chunk)
        case .appended(let chunk):
            guard !chunk.lines.isEmpty else {
                endOffset = chunk.endOffset
                return
            }
            loadedLines.append(contentsOf: makeAppendedLines(chunk.lines))
            endOffset = chunk.endOffset
            trimRetainedLinesIfNeeded()
            rebuildVisibleLines()
        }
    }

    private func applyReload(_ chunk: AppLogService.LogChunk) {
        loadedLines = chunk.lines.enumerated().map { index, line in
            VisibleLine(id: index, text: line.isEmpty ? " " : line)
        }
        firstLoadedID = loadedLines.first?.id ?? 0
        nextAppendedID = (loadedLines.last?.id ?? -1) + 1
        startOffset = chunk.startOffset
        endOffset = chunk.endOffset
        hasOlderLines = chunk.startOffset > 0
        rebuildVisibleLines()
    }

    private func trimRetainedLinesIfNeeded() {
        let overflow = loadedLines.count - Self.maxRetainedLines
        guard overflow > 0 else { return }
        loadedLines.removeFirst(overflow)
        firstLoadedID = loadedLines.first?.id ?? nextAppendedID
        hasOlderLines = true
    }

    private func rebuildVisibleLines() {
        loadedLineCount = loadedLines.count
        let trimmedQuery = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredLines: [VisibleLine]
        if trimmedQuery.isEmpty {
            filteredLines = loadedLines
        } else {
            let needle = trimmedQuery.lowercased()
            filteredLines = loadedLines.filter { $0.text.lowercased().contains(needle) }
        }
        matchCount = filteredLines.count
        visibleLines = filteredLines
        contentVersion &+= 1
    }

    private func makePrependedLines(_ lines: [String]) -> [VisibleLine] {
        var nextID = firstLoadedID
        let entries = Array(lines.reversed().map { line in
            nextID -= 1
            return VisibleLine(id: nextID, text: line.isEmpty ? " " : line)
        }.reversed())
        firstLoadedID = entries.first?.id ?? firstLoadedID
        return entries
    }

    private func makeAppendedLines(_ lines: [String]) -> [VisibleLine] {
        let startID = nextAppendedID
        let entries = lines.enumerated().map { index, line in
            VisibleLine(id: startID + index, text: line.isEmpty ? " " : line)
        }
        nextAppendedID = startID + lines.count
        return entries
    }
}
