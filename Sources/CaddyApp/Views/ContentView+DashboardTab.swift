import SwiftUI

extension ContentView {
    func dashboardSection(_ snapshot: DashboardSnapshot) -> some View {
        GroupBox("Dashboard") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    dashboardStatusCard(
                        title: "Läuft Caddy?",
                        isPositive: snapshot.caddyRuntimeStatus.isRunning,
                        detail: snapshot.caddyRuntimeStatus.adminEndpoint,
                        color: snapshot.caddyRuntimeStatus.isRunning ? .green : .orange
                    )

                    dashboardStatusCard(
                        title: "Ist das Cert gültig?",
                        isPositive: isCertificateValid(snapshot),
                        detail: snapshot.tlsStatus.systemKeychainTrustStatus.label,
                        color: isCertificateValid(snapshot) ? .green : .orange
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    dashboardMetricCard(
                        title: "Caddy",
                        value: snapshot.caddyInstall.isInstalled ? "Installiert" : "Nicht installiert",
                        tone: snapshot.caddyInstall.isInstalled ? .green : .orange
                    )
                    dashboardMetricCard(
                        title: "Version",
                        value: snapshot.caddyInstall.version ?? "unknown",
                        isMonospaced: true
                    )
                    dashboardMetricCard(title: "Routen", value: "\(snapshot.configPreview.routeCount)")
                    dashboardMetricCard(title: "Targets", value: "\(snapshot.runtimeTargets.count)")
                }

                dashboardQuickAccessSection(snapshot)

                HStack {
                    Text("Snapshot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    func dashboardStatusCard(
        title: String,
        isPositive: Bool,
        detail: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityLabel(isPositive ? "Ja" : "Nein")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    func dashboardMetricCard(
        title: String,
        value: String,
        tone: Color = .accentColor,
        isMonospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .fontWeight(.semibold)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tone.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    func dashboardQuickAccessSection(_ snapshot: DashboardSnapshot) -> some View {
        let multipassTargets = snapshot.runtimeTargets.filter { target in
            target.source == .multipass && target.status.lowercased() == "running"
        }
        let podTargets = snapshot.runtimeTargets.filter { $0.source == .podman }

        if !multipassTargets.isEmpty || !podTargets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Access")
                    .font(.headline)

                if !multipassTargets.isEmpty {
                    dashboardRuntimeCardGroup(
                        title: "Multipass VMs",
                        icon: "shippingbox",
                        targets: multipassTargets
                    )
                }

                if !podTargets.isEmpty {
                    dashboardRuntimeCardGroup(
                        title: "Pods (Podman)",
                        icon: "square.stack.3d.up",
                        targets: podTargets
                    )
                }
            }
        }
    }

    func dashboardRuntimeCardGroup(
        title: String,
        icon: String,
        targets: [RuntimeTarget]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title) (\(targets.count))", systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                ForEach(targets) { target in
                    dashboardRuntimeLinkCard(target)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    func dashboardRuntimeLinkCard(_ target: RuntimeTarget) -> some View {
        let destination = runtimeDashboardURL(for: target)

        return Button {
            guard let destination else { return }
            openURL(destination)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(target.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(target.source == .multipass ? "Multipass VM" : "Podman Pod")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(destination == nil ? .tertiary : .secondary)
                }

                if let displayURL = runtimeDashboardURLDisplayString(for: target) {
                    Text(displayURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Kein Browser-Link verfügbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(target.status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(target.address)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(destination == nil)
    }

    @ViewBuilder
    func warningSection(_ warnings: [String]) -> some View {
        if !warnings.isEmpty {
            GroupBox("Warnings") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                        Text("• \(warning)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    func autoSetupSection(_ report: AutoSetupReport) -> some View {
        if report.attempted {
            GroupBox("Automatic Setup") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.operations) { operation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(operation.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                Spacer()
                                Text(operation.succeeded ? "Success" : "Failed")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((operation.succeeded ? Color.green : Color.red).opacity(0.16))
                                    .foregroundStyle(operation.succeeded ? .green : .red)
                                    .clipShape(Capsule())
                            }
                            Text(operation.message)
                            if !operation.output.isEmpty {
                                Text(operation.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Text(operation.performedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
