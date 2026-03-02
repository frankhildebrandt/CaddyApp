import SwiftUI

struct OnDemandShellView: View {
    @ObservedObject var shellSession: OnDemandEmbeddedShellSession
    @Binding var shellInput: String
    let app: OnDemandAppDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(shellSession.statusMessage.isEmpty ? "Shell in der App" : shellSession.statusMessage)
                    .font(.caption)
                    .foregroundStyle(shellSession.isRunning ? .green : .secondary)
                Spacer()
                Button("Neu verbinden") {
                    shellSession.restart(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Interaktive Shell direkt im Tab (kein externes Terminal).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Befehl eingeben", text: $shellInput)
                    .textFieldStyle(.roundedBorder)
                Button("Senden") {
                    let command = shellInput
                    shellInput = ""
                    shellSession.send(command)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!shellSession.isRunning)
            }

            if shellSession.output.isEmpty {
                Text("Shell wird initialisiert...")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                TextEditor(text: .constant(shellSession.output))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 260)
            }
        }
    }
}
