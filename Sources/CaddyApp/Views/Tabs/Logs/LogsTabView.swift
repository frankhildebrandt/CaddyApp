import SwiftUI

struct LogsTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    private let logBottomAnchor = "logs-bottom"

    var body: some View {
        let display = displayedLogLines(viewModel.appLogText, query: viewModel.logFilterQuery)

        return GroupBox("Logging / Debug") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Enthält CLI-Kommandos (inkl. Exit-Code/Output) sowie Start/Stop-Ereignisse für Caddy und On-Demand-Apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Logs aktualisieren") {
                        viewModel.refreshLogs()
                    }
                    .disabled(viewModel.isRefreshingLogs)

                    Toggle("Live", isOn: Binding(
                        get: { viewModel.isLogLiveWatchEnabled },
                        set: { viewModel.setLogLiveWatchEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Button("Logs leeren", role: .destructive) {
                        viewModel.clearLogs()
                    }

                    if viewModel.isRefreshingLogs {
                        InlineActivitySkeleton()
                    }

                    Spacer()

                    Text(AppPaths.appLogFile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    TextField("Filter (z. B. app=Grafana)", text: $viewModel.logFilterQuery)
                        .textFieldStyle(.roundedBorder)
                    if !viewModel.logFilterQuery.isEmpty {
                        Button("Filter löschen") {
                            viewModel.logFilterQuery = ""
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("Zeige \(display.visible.count) von \(display.totalCount) Zeilen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if display.wasTrimmed {
                        Text("Ansicht ist auf die letzten \(DashboardViewModel.maxVisibleLogLines) Zeilen begrenzt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if display.visible.isEmpty {
                    Text("Noch keine Logs vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(display.visible.enumerated()), id: \.offset) { index, line in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(display.firstVisibleLineNumber + index)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 56, alignment: .trailing)
                                        Text(line.isEmpty ? " " : line)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id(logBottomAnchor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 420)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onAppear {
                            scrollToBottom(using: proxy)
                        }
                        .onChange(of: viewModel.appLogText) { _, _ in
                            guard viewModel.isLogLiveWatchEnabled else { return }
                            scrollToBottom(using: proxy)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            viewModel.refreshLogs()
            viewModel.setLogLiveWatchEnabled(viewModel.isLogLiveWatchEnabled)
        }
        .onDisappear {
            viewModel.stopLogLiveWatch()
        }
    }

    private func displayedLogLines(_ logText: String, query: String) -> (visible: [String], totalCount: Int, firstVisibleLineNumber: Int, wasTrimmed: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = logText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let filtered: [String]
        if trimmed.isEmpty {
            filtered = lines
        } else {
            let needle = trimmed.lowercased()
            filtered = lines.filter { $0.lowercased().contains(needle) }
        }
        let visible = Array(filtered.suffix(DashboardViewModel.maxVisibleLogLines))
        let firstVisibleLineNumber = max(filtered.count - visible.count + 1, 1)
        return (
            visible: visible,
            totalCount: filtered.count,
            firstVisibleLineNumber: firstVisibleLineNumber,
            wasTrimmed: filtered.count > visible.count
        )
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(logBottomAnchor, anchor: .bottom)
            }
        }
    }
}
