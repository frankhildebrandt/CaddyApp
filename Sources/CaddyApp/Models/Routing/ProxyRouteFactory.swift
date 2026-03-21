import Foundation

enum ProxyRouteFactory {
    static func build(
        runtimeTargets: [RuntimeTarget],
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft],
        multipassServices: [MultipassServiceDraft],
        gatewayPort: UInt16
    ) -> [ProxyRoute] {
        customRoutes.map { $0.asProxyRoute() }
            + onDemandApps.map { $0.asProxyRoute(gatewayPort: gatewayPort) }
            + multipassServiceRoutes(from: multipassServices, runtimeTargets: runtimeTargets, gatewayPort: gatewayPort)
            + multipassRoutes(from: runtimeTargets)
    }

    private static func multipassRoutes(from targets: [RuntimeTarget]) -> [ProxyRoute] {
        targets
            .filter { $0.source == .multipass }
            .flatMap { target -> [ProxyRoute] in
                guard let vmLabel = DNSLabel.normalize(target.name) else { return [] }
                guard target.address != "(no ip)" else { return [] }
                let enabled = target.status.lowercased() == "running"
                let apexHost = "\(vmLabel).mp.localhost"
                return [
                    ProxyRoute(
                        host: apexHost,
                        upstream: target.address,
                        source: .multipass,
                        enabled: enabled
                    ),
                    ProxyRoute(
                        host: "*.\(apexHost)",
                        upstream: target.address,
                        source: .multipass,
                        enabled: enabled
                    )
                ]
            }
    }

    private static func multipassServiceRoutes(
        from services: [MultipassServiceDraft],
        runtimeTargets: [RuntimeTarget],
        gatewayPort: UInt16
    ) -> [ProxyRoute] {
        let multipassIPsByVM = Dictionary(
            uniqueKeysWithValues: runtimeTargets.compactMap { target -> (String, String)? in
                guard target.source == .multipass, target.address != "(no ip)" else { return nil }
                guard let host = upstreamHost(from: target.address) else { return nil }
                return (target.name.lowercased(), host)
            }
        )

        return services.flatMap { service in
            let direct: ProxyRoute
            if let vmAddress = multipassIPsByVM[service.vmName.lowercased()] {
                direct = ProxyRoute(
                    host: service.host,
                    upstream: "\(vmAddress):\(service.targetPort)",
                    source: .multipassService,
                    enabled: service.enabled,
                    onDemandGatewayEndpoint: "127.0.0.1:\(gatewayPort)"
                )
            } else {
                direct = service.asProxyRoute(gatewayPort: gatewayPort)
            }
            let wildcard = ProxyRoute(
                host: "*.\(service.host)",
                upstream: direct.upstream,
                source: .multipassService,
                enabled: direct.enabled,
                onDemandGatewayEndpoint: direct.onDemandGatewayEndpoint
            )
            return [direct, wildcard]
        }
    }

    private static func upstreamHost(from address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("://"), let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            return host
        }

        return trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
