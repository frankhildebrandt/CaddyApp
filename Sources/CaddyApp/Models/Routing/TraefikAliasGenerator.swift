import Foundation

enum TraefikAliasGenerator {
    static func hosts(for host: String, ips: [String], enabled: Bool) -> [String] {
        var hosts: [String] = [host]
        guard enabled, host.hasSuffix(".localhost"), !host.contains("*") else { return hosts }

        let baseHost = String(host.dropLast(".localhost".count))
        guard !baseHost.isEmpty else { return hosts }

        for ipAddress in ips {
            hosts.append("\(baseHost).\(ipAddress).traefik.me")
        }

        var seen = Set<String>()
        return hosts.filter { seen.insert($0).inserted }
    }
}
