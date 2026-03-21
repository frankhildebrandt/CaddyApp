import Darwin
import Foundation

struct CaddyConfigService {
    func routes(
        runtimeTargets: [RuntimeTarget],
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft],
        multipassServices: [MultipassServiceDraft]
    ) -> [ProxyRoute] {
        ProxyRouteFactory.build(
            runtimeTargets: runtimeTargets,
            customRoutes: customRoutes,
            onDemandApps: onDemandApps,
            multipassServices: multipassServices,
            gatewayPort: OnDemandAppsService.gatewayPort
        )
    }

    func preview(
        for routes: [ProxyRoute],
        additionalCaddyfileConfig: String,
        enableTraefikMeAliases: Bool
    ) -> CaddyConfigPreview {
        let enabledRoutes = routes.filter(\.enabled)
        let caddyfile = generateCaddyfile(
            for: enabledRoutes,
            additionalCaddyfileConfig: additionalCaddyfileConfig,
            enableTraefikMeAliases: enableTraefikMeAliases
        )

        return CaddyConfigPreview(
            caddyfilePath: AppPaths.appSupportDirectory.appendingPathComponent("Caddyfile", isDirectory: false).path,
            generatedCaddyfile: caddyfile,
            routeCount: enabledRoutes.count
        )
    }

    func generateCaddyfile(
        for routes: [ProxyRoute],
        additionalCaddyfileConfig: String,
        enableTraefikMeAliases: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("{")
        lines.append("    admin localhost:2019")
        lines.append("}")
        lines.append("")

        let interfaceIPv4Addresses = macInterfaceIPv4Addresses()
        for route in routes {
            let siteHosts = TraefikAliasGenerator.hosts(
                for: route.host,
                ips: interfaceIPv4Addresses,
                enabled: enableTraefikMeAliases
            )
            lines.append("\(siteHosts.joined(separator: ", ")) {")
            lines.append("    tls internal")
            if let gatewayEndpoint = route.onDemandGatewayEndpoint {
                lines.append("    route {")
                lines.append("        reverse_proxy \(route.upstream) \(gatewayEndpoint) {")
                lines.append("            lb_policy first")
                lines.append("            lb_retries 1")
                lines.append("            lb_try_duration 5s")
                lines.append("            lb_try_interval 100ms")
                lines.append("            transport http {")
                lines.append("                dial_timeout 250ms")
                lines.append("            }")
                lines.append("        }")
                lines.append("    }")
            } else {
                lines.append("    reverse_proxy \(route.upstream)")
            }
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

    private func macInterfaceIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var ifaddrsPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPointer) == 0, let firstAddress = ifaddrsPointer else { return [] }
        defer { freeifaddrs(ifaddrsPointer) }

        var currentAddress: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let address = currentAddress {
            defer { currentAddress = address.pointee.ifa_next }

            let flags = Int32(address.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback else { continue }

            guard let socketAddress = address.pointee.ifa_addr, socketAddress.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var ipBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let getNameInfoResult = getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &ipBuffer,
                socklen_t(ipBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard getNameInfoResult == 0 else { continue }

            let rawIP = ipBuffer.prefix { $0 != 0 }
            let ipAddress = String(decoding: rawIP.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard !ipAddress.hasPrefix("169.254.") else { continue }

            addresses.append(ipAddress)
        }

        return Array(Set(addresses)).sorted()
    }
}
