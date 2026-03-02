import SwiftUI

extension ContentView {
    func systemSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Caddy / TLS") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Caddy installed") {
                    Text(snapshot.caddyInstall.isInstalled ? "Yes" : "No")
                }
                LabeledContent("Binary path") {
                    Text(snapshot.caddyInstall.binaryPath ?? "-")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Local version") {
                    Text(snapshot.caddyInstall.version ?? "unknown")
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Latest release") {
                    if let latest = snapshot.latestRelease {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.tagName)
                            if let publishedAt = latest.publishedAt {
                                Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let url = latest.url {
                                Link(url.absoluteString, destination: url)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text("Unavailable")
                    }
                }
                LabeledContent("Update command") {
                    Text(snapshot.caddyInstall.suggestedInstallCommand)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Update available") {
                    if !snapshot.caddyUpdateStatus.checked {
                        Text("Unknown (release check unavailable)")
                    } else {
                        if snapshot.caddyUpdateStatus.updateAvailable {
                            Text("Yes (new version available)")
                                .foregroundStyle(.orange)
                        } else {
                            Text("No (up to date)")
                                .foregroundStyle(.green)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button("Update Caddy") {
                        showCaddyUpdateConfirmation = true
                    }
                    .disabled(
                        !snapshot.caddyInstall.isInstalled
                        || !snapshot.caddyUpdateStatus.checked
                        || !snapshot.caddyUpdateStatus.updateAvailable
                    )

                    if viewModel.isUpdatingCaddy {
                        InlineActivitySkeleton()
                    }
                }
                if let updateOperation = viewModel.lastCaddyUpdateOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(updateOperation.message)
                            .foregroundStyle(updateOperation.succeeded ? .green : .red)
                        if let previous = updateOperation.previousVersion, let current = updateOperation.currentVersion {
                            Text("Version: \(previous) -> \(current)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if updateOperation.recoveryAttempted {
                            Text("Recovery attempted: \(updateOperation.recoverySucceeded == true ? "yes (success)" : "yes (failed)")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !updateOperation.output.isEmpty {
                            Text(updateOperation.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(updateOperation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Divider()
                LabeledContent("Caddy runtime") {
                    Text(snapshot.caddyRuntimeStatus.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(snapshot.caddyRuntimeStatus.isRunning ? .green : .secondary)
                }
                Toggle(
                    "Caddy einschalten",
                    isOn: Binding(
                        get: { viewModel.snapshot?.caddyRuntimeStatus.isRunning ?? false },
                        set: { viewModel.setCaddyRunning($0) }
                    )
                )
                .disabled(
                    !snapshot.caddyInstall.isInstalled
                    || viewModel.isChangingCaddyRuntime
                    || viewModel.isApplyingConfig
                )
                if viewModel.isChangingCaddyRuntime {
                    InlineActivitySkeleton()
                }
                LabeledContent("Root certificate") {
                    Text(snapshot.tlsStatus.rootCertificatePresent ? "Present" : "Missing")
                }
                LabeledContent("System Keychain trust") {
                    Text(snapshot.tlsStatus.systemKeychainTrustStatus.label)
                        .foregroundStyle(tlsTrustColor(snapshot.tlsStatus.systemKeychainTrustStatus))
                }
                LabeledContent("CA path") {
                    Text(snapshot.tlsStatus.localCARootPath)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("Trust command") {
                    Text(snapshot.tlsStatus.caddyTrustCommand)
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 10) {
                    Button("Trust Root CA (macOS Dialog)") {
                        viewModel.trustLocalCA()
                    }
                    .disabled(!snapshot.caddyInstall.isInstalled)

                    if viewModel.isApplyingTLSTrust {
                        InlineActivitySkeleton()
                    }
                }
                if let trustOperation = viewModel.lastTrustOperation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trustOperation.message)
                            .foregroundStyle(trustOperation.succeeded ? .green : .red)
                        if !trustOperation.output.isEmpty {
                            Text(trustOperation.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(trustOperation.performedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(snapshot.tlsStatus.systemKeychainTrustDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.tlsStatus.installHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }
}
