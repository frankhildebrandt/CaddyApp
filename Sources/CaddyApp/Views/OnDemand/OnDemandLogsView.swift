import SwiftUI

enum OnDemandLogsKind {
    case host
    case container
    case event
}

struct OnDemandLogsView: View {
    let kind: OnDemandLogsKind
    let app: OnDemandAppDraft
    let text: String
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aktualisieren", action: onRefresh)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isLoading)
            }

            if isLoading {
                InlineActivitySkeleton()
            }

            if text.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(text))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 180)
            }
        }
    }

    private var title: String {
        switch kind {
        case .host:
            return "Gefilterte Host-Logs aus dem App-Log"
        case .container:
            return "Container/Pod-Logs (\(app.runtime.label))"
        case .event:
            return "Eventlog (Create, Start, Stop, Backup, ...)"
        }
    }

    private var emptyText: String {
        switch kind {
        case .host:
            return "Keine passenden Host-Log-Zeilen gefunden."
        case .container:
            return "Noch keine Container/Pod-Logs geladen."
        case .event:
            return "Keine passenden Event-Zeilen gefunden."
        }
    }
}
