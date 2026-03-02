import SwiftUI

extension ContentView {
    func featureSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Feature Progress") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.features) { feature in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(feature.id) · \(feature.title)")
                                .font(.headline)
                            Text(feature.summary)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Text(feature.documentPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(feature.status.label)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(feature.status).opacity(0.16))
                            .foregroundStyle(statusColor(feature.status))
                            .clipShape(Capsule())
                    }
                    Divider()
                }
                Text("Last snapshot: \(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
