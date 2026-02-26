import Foundation

struct RuntimeDiscoveryService {
    private let shell = ShellCommandRunner()
    private let multipassHTTPPorts = [80, 8080, 8081, 3000, 8090]
    private let multipassHTTPSPorts = [443, 8443]

    func discoverTargets() -> [RuntimeTarget] {
        var targets: [RuntimeTarget] = []
        targets.append(contentsOf: discoverMultipass())
        targets.append(contentsOf: discoverPodman())
        return targets
    }

    private func discoverMultipass() -> [RuntimeTarget] {
        let listResult = shell.runShell("multipass list --format json")
        guard listResult.isSuccess else { return [] }

        guard let data = listResult.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["list"] as? [[String: Any]] else {
            return []
        }

        return list.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            let state = (item["state"] as? String) ?? "unknown"
            let ipv4 = (item["ipv4"] as? [String])?.first ?? ""
            let address = multipassAddress(for: ipv4)
            return RuntimeTarget(name: name, source: .multipass, address: address, status: state)
        }
    }

    private func discoverPodman() -> [RuntimeTarget] {
        let listResult = shell.runShell("podman ps --format json")
        guard listResult.isSuccess,
              let data = listResult.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return json.compactMap { item in
            let names = item["Names"] as? [String]
            let name = names?.first ?? (item["Names"] as? String) ?? "podman-container"
            let ports = (item["Ports"] as? [[String: Any]]) ?? []
            let hostPort = ports.first { ($0["host_port"] as? Int) != nil }?["host_port"] as? Int
            let port = hostPort.map(String.init) ?? "80"
            let state = (item["State"] as? String) ?? "running"
            return RuntimeTarget(name: name, source: .podman, address: "127.0.0.1:\(port)", status: state)
        }
    }

    private func multipassAddress(for ipv4: String) -> String {
        guard !ipv4.isEmpty else { return "(no ip)" }

        if let httpPort = firstReachableHTTPPort(on: ipv4) {
            return "\(ipv4):\(httpPort)"
        }

        if let httpsPort = firstReachableHTTPSPort(on: ipv4) {
            return "https://\(ipv4):\(httpsPort)"
        }

        return "\(ipv4):80"
    }

    private func firstReachableHTTPPort(on host: String) -> Int? {
        multipassHTTPPorts.first { port in
            probe(url: "http://\(host):\(port)")
        }
    }

    private func firstReachableHTTPSPort(on host: String) -> Int? {
        multipassHTTPSPorts.first { port in
            probe(url: "https://\(host):\(port)", insecureTLS: true)
        }
    }

    private func probe(url: String, insecureTLS: Bool = false) -> Bool {
        let escapedURL = shellEscape(url)
        let insecureFlag = insecureTLS ? "-k " : ""
        let command = "curl \(insecureFlag)-sS -o /dev/null --connect-timeout 1 --max-time 2 '\(escapedURL)'"
        return shell.runShell(command).isSuccess
    }

    private func shellEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\\''")
    }
}
