import Foundation
import SwiftUI

struct OnDemandListView: View {
    let apps: [OnDemandAppDraft]
    let statusesByID: [UUID: OnDemandAppRuntimeStatus]
    let phaseColor: (OnDemandAppPhase) -> Color
    let onSelect: (OnDemandAppDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            overviewMetrics

            ForEach(apps) { app in
                let runtimeStatus = statusesByID[app.id]
                Button {
                    onSelect(app)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(app.enabled ? phaseColor(runtimeStatus?.phase ?? .stopped) : .secondary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 8) {
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
                            HStack(spacing: 8) {
                                metricChip("Phase", (runtimeStatus?.phase.label ?? OnDemandAppPhase.stopped.label).capitalized)
                                metricChip("Cold Starts", "\(runtimeStatus?.coldStartCount ?? 0)")
                                metricChip("Warm-up", warmupValue(for: runtimeStatus))
                                metricChip("Letzter Zugriff", accessValue(for: runtimeStatus))
                            }
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

    private var overviewMetrics: some View {
        let statuses = apps.compactMap { statusesByID[$0.id] }
        let runningCount = statuses.filter { $0.phase == .running }.count
        let startingCount = statuses.filter { $0.phase == .starting }.count
        let errorCount = statuses.filter { $0.phase == .error }.count
        let coldStarts = statuses.reduce(0) { $0 + $1.coldStartCount }
        let warmupSamples = statuses.compactMap(\.lastWarmupDurationMs)
        let averageWarmup = warmupSamples.isEmpty ? nil : warmupSamples.reduce(0, +) / warmupSamples.count

        return HStack(spacing: 10) {
            metricCard(title: "Apps", value: "\(apps.count)", detail: "\(runningCount) aktiv")
            metricCard(title: "Starts", value: "\(coldStarts)", detail: "\(startingCount) starten")
            metricCard(title: "Warm-up Ø", value: averageWarmup.map(formatDuration) ?? "n/a", detail: "\(errorCount) Fehler")
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
        .font(.caption2.monospaced())
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }

    private func warmupValue(for status: OnDemandAppRuntimeStatus?) -> String {
        guard let milliseconds = status?.lastWarmupDurationMs else { return "n/a" }
        return formatDuration(milliseconds)
    }

    private func accessValue(for status: OnDemandAppRuntimeStatus?) -> String {
        guard let lastAccessAt = status?.lastAccessAt else { return "nie" }
        let seconds = max(Int(Date().timeIntervalSince(lastAccessAt)), 0)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h"
    }

    private func formatDuration(_ milliseconds: Int) -> String {
        if milliseconds < 1000 {
            return "\(milliseconds)ms"
        }
        return String(format: "%.1fs", Double(milliseconds) / 1000.0)
    }
}
