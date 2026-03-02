import SwiftUI

extension ContentView {
    func runtimeSection(_ snapshot: DashboardSnapshot) -> some View {
        let podmanTargets = snapshot.runtimeTargets.filter { $0.source == .podman }

        return VStack(alignment: .leading, spacing: 16) {
            GroupBox("Runtime Discovery (Podman)") {
                VStack(alignment: .leading, spacing: 8) {
                    if podmanTargets.isEmpty {
                        Text("Keine Podman Runtime Targets erkannt.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(podmanTargets) { target in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(target.name)
                                            .font(.headline)
                                        Text(target.source.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(target.address)
                                    .font(.system(.body, design: .monospaced))
                                Text(target.status)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

}
