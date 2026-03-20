import SwiftUI

struct DashboardTabView: View {
    let snapshot: DashboardSnapshot
    let openURLAction: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heroSection

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                statusCard(
                    title: "Caddy Runtime",
                    isPositive: snapshot.caddyRuntimeStatus.isRunning,
                    detail: snapshot.caddyRuntimeStatus.adminEndpoint,
                    color: snapshot.caddyRuntimeStatus.isRunning ? .green : .orange
                )

                statusCard(
                    title: "TLS Vertrauen",
                    isPositive: isCertificateValid,
                    detail: snapshot.tlsStatus.systemKeychainTrustStatus.label,
                    color: isCertificateValid ? .green : .orange
                )

                metricCard(
                    title: "Install Status",
                    value: snapshot.caddyInstall.isInstalled ? "Installiert" : "Fehlt",
                    tone: snapshot.caddyInstall.isInstalled ? .green : .orange
                )

                metricCard(
                    title: "Version",
                    value: snapshot.caddyInstall.version ?? "unknown",
                    isMonospaced: true
                )
            }

            if !snapshot.warnings.isEmpty {
                warningSection
            }

            if snapshot.autoSetupReport.attempted {
                setupSection
            }

            quickAccessSection
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Starte deine lokale Plattform")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .frame(height: 58)
                .overlay(alignment: .leading) {
                    Text("Domains, Services oder Logs direkt im Blick behalten…")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppChrome.secondaryText)
                        .padding(.horizontal, 22)
                }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                actionCard(title: "Routing prüfen", icon: "arrow.triangle.branch", summary: "\(snapshot.configPreview.routeCount) aktive Routen")
                actionCard(title: "Services öffnen", icon: "shippingbox", summary: "\(snapshot.runtimeTargets.count) erkannte Targets")
                actionCard(title: "TLS Status", icon: "lock.shield", summary: snapshot.tlsStatus.systemKeychainTrustStatus.label)
                actionCard(title: "Logs & Monitoring", icon: "waveform.path.ecg", summary: snapshot.generatedAt.formatted(date: .omitted, time: .shortened))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text("Hinweise")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(snapshot.warnings.enumerated()), id: \.offset) { _, warning in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        Text(warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(22)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte automatische Aktionen")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.autoSetupReport.operations) { operation in
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
            .padding(22)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    private var isCertificateValid: Bool {
        snapshot.tlsStatus.rootCertificatePresent
            && snapshot.tlsStatus.systemKeychainTrustStatus == .trusted
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        let multipassTargets = snapshot.runtimeTargets.filter { target in
            target.source == .multipass && target.status.lowercased() == "running"
        }
        let podTargets = snapshot.runtimeTargets.filter { $0.source == .podman }

        if !multipassTargets.isEmpty || !podTargets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Schnellzugriff")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppChrome.primaryText)

                if !multipassTargets.isEmpty {
                    runtimeCardGroup(
                        title: "Multipass VMs",
                        icon: "shippingbox",
                        targets: multipassTargets
                    )
                }

                if !podTargets.isEmpty {
                    runtimeCardGroup(
                        title: "Pods (Podman)",
                        icon: "square.stack.3d.up",
                        targets: podTargets
                    )
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
        }
    }

    private func runtimeCardGroup(
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
                    runtimeLinkCard(target)
                }
            }
        }
        .padding(10)
    }

    private func runtimeLinkCard(_ target: RuntimeTarget) -> some View {
        let destination = runtimeDashboardURL(for: target)

        return Button {
            guard let destination else { return }
            openURLAction(destination)
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppChrome.tileSoftFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(destination == nil)
    }

    private func statusCard(
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1.2)
        )
    }

    private func metricCard(
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tone.opacity(0.16), lineWidth: 1)
        )
    }

    private func actionCard(title: String, icon: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppChrome.primaryText)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppChrome.primaryText)
            Text(summary)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppChrome.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppChrome.tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.88), lineWidth: 1)
        )
    }

    private func runtimeDashboardURL(for target: RuntimeTarget) -> URL? {
        let address = target.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return nil }
        let scheme = target.source == .multipass ? "http" : "http"
        return URL(string: "\(scheme)://\(address)")
    }

    private func runtimeDashboardURLDisplayString(for target: RuntimeTarget) -> String? {
        runtimeDashboardURL(for: target)?.absoluteString
    }
}
