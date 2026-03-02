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
            + multipassServiceRoutes(from: multipassServices, gatewayPort: gatewayPort)
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

    private static func multipassServiceRoutes(from services: [MultipassServiceDraft], gatewayPort: UInt16) -> [ProxyRoute] {
        services.flatMap { service in
            let direct = service.asProxyRoute(gatewayPort: gatewayPort)
            let wildcard = ProxyRoute(
                host: "*.\(service.host)",
                upstream: direct.upstream,
                source: .multipassService,
                enabled: direct.enabled
            )
            return [direct, wildcard]
        }
    }
}
