import SwiftUI

extension ContentView {
    func configSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Reverse Proxy Configuration Preview") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Managed routes") {
                    Text("\(snapshot.configPreview.routeCount)")
                }
                LabeledContent("Target Caddyfile") {
                    Text(snapshot.configPreview.caddyfilePath)
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 10) {
                    Button("Write Config") {
                        viewModel.writeConfigPreview()
                    }
                    Button("Validate") {
                        viewModel.validateConfigPreview()
                    }
                    Button("Reload Caddy") {
                        showReloadConfigConfirmation = true
                    }
                    .disabled(!snapshot.caddyInstall.isInstalled)

                    if viewModel.isApplyingConfig {
                        InlineActivitySkeleton()
                    }
                }
                .disabled(viewModel.isApplyingConfig || viewModel.isLoading || viewModel.isChangingCaddyRuntime)

                if let operation = viewModel.lastConfigOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(operation.kind.rawValue.capitalized): \(operation.message)")
                            .foregroundStyle(operation.succeeded ? .green : .red)
                        if !operation.output.isEmpty {
                            Text(operation.output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        Text(operation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                TextEditor(text: .constant(snapshot.configPreview.generatedCaddyfile))
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 240)
            }
            .padding(.top, 4)
        }
    }
}
