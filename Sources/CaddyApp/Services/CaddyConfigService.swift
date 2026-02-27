import Darwin
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
        lines.append("    auto_tls")
        lines.append("}")
        lines.append("")

        let interfaceIPv4Addresses = macInterfaceIPv4Addresses()
        for route in routes {
            let siteHosts = siteHosts(for: route.host, interfaceIPv4Addresses: interfaceIPv4Addresses)
            lines.append("\(siteHosts.joined(separator: ", ")) {")
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

    private func siteHosts(for host: String, interfaceIPv4Addresses: [String]) -> [String] {
        var hosts: [String] = [host]
        guard host.hasSuffix(".localhost"), !host.contains("*") else { return hosts }

        let baseHost = String(host.dropLast(".localhost".count))
        guard !baseHost.isEmpty else { return hosts }

        for ipAddress in interfaceIPv4Addresses {
            hosts.append("\(baseHost).\(ipAddress).traefik.me")
        }

        var seen = Set<String>()
        return hosts.filter { seen.insert($0).inserted }
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
