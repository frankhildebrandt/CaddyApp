import SwiftUI

struct OnDemandListView: View {
    let apps: [OnDemandAppDraft]
    let statusesByID: [UUID: OnDemandAppRuntimeStatus]
    let phaseColor: (OnDemandAppPhase) -> Color
    let onSelect: (OnDemandAppDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(apps) { app in
                let runtimeStatus = statusesByID[app.id]
                Button {
                    onSelect(app)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(app.enabled ? phaseColor(runtimeStatus?.phase ?? .stopped) : .secondary)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(app.name.isEmpty ? "Neue App" : app.name)
                                    .font(.headline)
                                Text(app.runtime.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(app.unitKind.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("https://\(app.host)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text("\(app.targetHost):\(app.targetPort) • idle \(app.idleTimeoutSeconds)s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
