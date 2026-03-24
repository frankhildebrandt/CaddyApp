import SwiftUI

struct LogsTabView: View {
    @StateObject private var logViewModel = LogViewportViewModel()
    private let logBottomAnchor = "logs-bottom"
    @State private var isNearBottom = true

    var body: some View {
        GroupBox("Logging / Debug") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Zeigt zunächst nur den Tail der Datei, streamt neue Zeilen live nach und lädt ältere Einträge beim Hochscrollen nach.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Logs aktualisieren") {
                        Task {
                            await logViewModel.reloadTail()
                        }
                    }
                    .disabled(logViewModel.isRefreshing)

                    Toggle("Live", isOn: Binding(
                        get: { logViewModel.liveEnabled },
                        set: { logViewModel.setLiveEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Button("Logs leeren", role: .destructive) {
                        Task {
                            await logViewModel.clearLogs()
                        }
                    }

                    if logViewModel.isRefreshing {
                        InlineActivitySkeleton()
                    }

                    Spacer()

                    Text(AppPaths.appLogFile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    TextField(
                        "Filter (z. B. app=Grafana)",
                        text: Binding(
                            get: { logViewModel.filterQuery },
                            set: { logViewModel.updateFilterQuery($0) }
                        )
                    )
                        .textFieldStyle(.roundedBorder)
                    if !logViewModel.filterQuery.isEmpty {
                        Button("Filter löschen") {
                            logViewModel.updateFilterQuery("")
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("Geladen: \(logViewModel.loadedLineCount) Zeilen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !logViewModel.filterQuery.isEmpty {
                        Text("Treffer: \(logViewModel.matchCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if logViewModel.hasOlderLines {
                        Text("Beim Hochscrollen werden ältere Zeilen nachgeladen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if logViewModel.visibleLines.isEmpty {
                    Text("Noch keine Logs vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                if let firstLine = logViewModel.visibleLines.first {
                                    Color.clear
                                        .frame(height: 1)
                                        .id("logs-top-anchor")
                                        .onAppear {
                                            Task {
                                                let anchorID = firstLine.id
                                                await logViewModel.loadOlderIfNeeded()
                                                await MainActor.run {
                                                    proxy.scrollTo(anchorID, anchor: .top)
                                                }
                                            }
                                        }
                                }

                                ForEach(logViewModel.visibleLines) { line in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(line.text)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id(logBottomAnchor)
                                    .onAppear {
                                        isNearBottom = true
                                    }
                                    .onDisappear {
                                        isNearBottom = false
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 420)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onAppear {
                            scrollToBottom(using: proxy)
                        }
                        .onChange(of: logViewModel.contentVersion) { _, _ in
                            guard logViewModel.liveEnabled, isNearBottom else { return }
                            scrollToBottom(using: proxy)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .task {
            await logViewModel.loadInitialTail()
            logViewModel.startLiveWatch()
        }
        .onDisappear {
            logViewModel.stopLiveWatch()
        }
        .onChange(of: logViewModel.liveEnabled) { _, enabled in
            if enabled {
                logViewModel.startLiveWatch()
            } else {
                logViewModel.stopLiveWatch()
            }
        }
    }
    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(logBottomAnchor, anchor: .bottom)
            }
        }
    }
}
