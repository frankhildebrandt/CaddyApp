import Foundation
import Network

struct RuntimeDiscoveryService {
    private let shell = ShellCommandRunner()
    private let multipassHTTPPorts = [8080, 80, 8081, 3000, 8090]
    private let multipassHTTPSPorts = [443, 8443]
    private let runtimeCommandTimeout: TimeInterval = 4
    private let guestPortCommandTimeout: TimeInterval = 3

    func discoverTargets() -> [RuntimeTarget] {
        var targets: [RuntimeTarget] = []
        targets.append(contentsOf: discoverMultipass())
        targets.append(contentsOf: discoverPodman())
        return targets
    }

    private func discoverMultipass() -> [RuntimeTarget] {
        let listResult = shell.runShellWithBackoff(
            "multipass list --format json",
            key: "runtime-discovery.multipass.list",
            label: "Multipass",
            timeout: runtimeCommandTimeout
        )
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
            let address = multipassAddress(for: ipv4, vmName: name, state: state)
            return RuntimeTarget(name: name, source: .multipass, address: address, status: state)
        }
    }

    private func discoverPodman() -> [RuntimeTarget] {
        let listResult = shell.runShellWithBackoff(
            "podman ps --format json",
            key: "runtime-discovery.podman.ps",
            label: "Podman",
            timeout: runtimeCommandTimeout
        )
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

    private func multipassAddress(for ipv4: String, vmName: String, state: String) -> String {
        guard !ipv4.isEmpty else { return "(no ip)" }

        if let httpPort = firstReachableHTTPPort(on: ipv4) {
            return "\(ipv4):\(httpPort)"
        }

        if let httpsPort = firstReachableHTTPSPort(on: ipv4) {
            return "https://\(ipv4):\(httpsPort)"
        }

        if state.lowercased() == "running",
           let guestHTTPPort = firstGuestListeningHTTPPort(vmName: vmName) {
            return "\(ipv4):\(guestHTTPPort)"
        }

        return "\(ipv4):\(multipassHTTPPorts.first ?? 8080)"
    }

    private func firstReachableHTTPPort(on host: String) -> Int? {
        multipassHTTPPorts.first { port in
            tcpProbe(host: host, port: port)
        }
    }

    private func firstReachableHTTPSPort(on host: String) -> Int? {
        multipassHTTPSPorts.first { port in
            probe(url: "https://\(host):\(port)", insecureTLS: true)
        }
    }

    private func probe(url: String, insecureTLS: Bool = false) -> Bool {
        guard let endpoint = URL(string: url) else { return false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2

        let delegate = ProbeURLSessionDelegate(allowInsecureTLS: insecureTLS)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let semaphore = DispatchSemaphore(value: 0)
        let probeResult = ProbeResult()

        let task = session.dataTask(with: request) { _, response, _ in
            if response != nil {
                probeResult.markReachable()
            }
            semaphore.signal()
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 3)
        task.cancel()
        session.invalidateAndCancel()
        return probeResult.isReachable
    }

    private func tcpProbe(host: String, port: Int) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "caddyapp.runtime-discovery.tcp-probe")
        let result = ProbeResult()

        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                result.markReachable()
                connection.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 2)
        connection.cancel()
        return result.isReachable
    }

    private func firstGuestListeningHTTPPort(vmName: String) -> Int? {
        let escapedVMName = shellEscape(vmName)
        let command = "multipass exec \(escapedVMName) -- sh -lc 'ss -H -ltn 2>/dev/null || netstat -ltn 2>/dev/null'"
        let result = shell.runShellWithBackoff(
            command,
            key: "runtime-discovery.multipass.guest-ports.\(vmName.lowercased())",
            label: "Multipass",
            timeout: guestPortCommandTimeout
        )
        guard result.isSuccess else { return nil }

        let output = result.stdout
        let ports = listeningPorts(from: output)
        return multipassHTTPPorts.first { ports.contains($0) }
    }

    private func listeningPorts(from output: String) -> Set<Int> {
        let pattern = #":([0-9]{2,5})(?:\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let matches = regex.matches(in: output, options: [], range: range)

        var ports: Set<Int> = []
        for match in matches {
            guard match.numberOfRanges > 1,
                  let portRange = Range(match.range(at: 1), in: output),
                  let port = Int(output[portRange]),
                  (1...65535).contains(port) else {
                continue
            }
            ports.insert(port)
        }
        return ports
    }

    private func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private final class ProbeURLSessionDelegate: NSObject, URLSessionDelegate {
    private let allowInsecureTLS: Bool

    init(allowInsecureTLS: Bool) {
        self.allowInsecureTLS = allowInsecureTLS
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard allowInsecureTLS,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

private final class ProbeResult: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isReachable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func markReachable() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
