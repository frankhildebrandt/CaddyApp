import Foundation

struct CaddyConfigService {
    func routes(
        runtimeTargets: [RuntimeTarget],
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft]
    ) -> [ProxyRoute] {
        customRoutes.map { $0.asProxyRoute() }
            + onDemandApps.map { $0.asProxyRoute(gatewayPort: OnDemandAppsService.gatewayPort) }
            + multipassRoutes(from: runtimeTargets)
    }

    func preview(for routes: [ProxyRoute], additionalCaddyfileConfig: String) -> CaddyConfigPreview {
        let enabledRoutes = routes.filter(\.enabled)
        let caddyfile = generateCaddyfile(for: enabledRoutes, additionalCaddyfileConfig: additionalCaddyfileConfig)

        return CaddyConfigPreview(
            caddyfilePath: AppPaths.appSupportDirectory.appendingPathComponent("Caddyfile", isDirectory: false).path,
            generatedCaddyfile: caddyfile,
            routeCount: enabledRoutes.count
        )
    }

    func generateCaddyfile(for routes: [ProxyRoute], additionalCaddyfileConfig: String) -> String {
        var lines: [String] = []
        lines.append("{")
        lines.append("    admin localhost:2019")
        lines.append("}")
        lines.append("")

        for route in routes {
            lines.append("\(route.host) {")
            lines.append("    tls internal")
            lines.append("    reverse_proxy \(route.upstream)")
            lines.append("}")
            lines.append("")
        }

        let trimmedAdditionalConfig = additionalCaddyfileConfig.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAdditionalConfig.isEmpty {
            lines.append("# Custom config")
            lines.append(trimmedAdditionalConfig)
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func multipassRoutes(from targets: [RuntimeTarget]) -> [ProxyRoute] {
        targets
            .filter { $0.source == .multipass }
            .flatMap { target -> [ProxyRoute] in
                guard let vmLabel = dnsLabel(from: target.name) else { return [] }
                guard target.address != "(no ip)" else { return [] }
                let enabled = target.status.lowercased() == "running"
                return [
                    ProxyRoute(
                        host: "\(vmLabel).mp.localhost",
                        upstream: target.address,
                        source: .multipass,
                        enabled: enabled
                    )
                ]
            }
    }

    private func dnsLabel(from input: String) -> String? {
        let lowered = input.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber || character == "-" {
                return character
            }
            return "-"
        }
        var label = String(mapped)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if label.isEmpty { return nil }
        if label.count > 63 {
            label = String(label.prefix(63)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        return label.isEmpty ? nil : label
    }
}
