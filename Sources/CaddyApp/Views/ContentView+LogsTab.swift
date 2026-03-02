import SwiftUI

extension ContentView {
    func loggingSection() -> some View {
        let filteredLogText = filteredLogs(viewModel.appLogText, query: viewModel.logFilterQuery)

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

                if filteredLogText.isEmpty {
                    Text("Noch keine Logs vorhanden.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                } else {
                    TextEditor(text: .constant(filteredLogText))
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 420)
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            viewModel.refreshLogs()
        }
    }
}
