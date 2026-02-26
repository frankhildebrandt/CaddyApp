import Foundation

struct EnvironmentBootstrapService {
    private let shell = ShellCommandRunner()
    private let installService = CaddyInstallationService()

    func runAutoSetupIfNeeded(caddyInstall: CaddyInstallStatus, tlsStatus: TLSStatus) -> AutoSetupReport {
        var operations: [SetupOperationResult] = []

        var currentInstall = caddyInstall
        if !currentInstall.isInstalled {
            let installResult = installCaddy()
            operations.append(installResult)
            currentInstall = CaddyInstallationService().loadStatus()
        }

        let currentTLS = LocalhostTLSService().status()
        if currentInstall.isInstalled && !currentTLS.rootCertificatePresent {
            operations.append(generateLocalCARoot())
        }

        return AutoSetupReport(
            attempted: !operations.isEmpty,
            operations: operations
        )
    }

    private func installCaddy() -> SetupOperationResult {
        installService.installForBootstrap()
    }

    private func generateLocalCARoot() -> SetupOperationResult {
        let supportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CaddyApp/bootstrap", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        } catch {
            return SetupOperationResult(
                kind: .generateLocalCA,
                succeeded: false,
                message: "Failed to create bootstrap directory for CA generation",
                output: error.localizedDescription,
                performedAt: Date()
            )
        }

        let configURL = supportDir.appendingPathComponent("generate-ca.Caddyfile")
        let adminAddress = "localhost:29201"
        let siteHost = "bootstrap-ca.localhost"
        let sitePort = 29443

        let config = """
        {
            admin \(adminAddress)
        }

        \(siteHost):\(sitePort) {
            tls internal
            respond \"bootstrap\" 200
        }
        """

        do {
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            return SetupOperationResult(
                kind: .generateLocalCA,
                succeeded: false,
                message: "Failed to write temporary bootstrap Caddyfile",
                output: error.localizedDescription,
                performedAt: Date()
            )
        }

        let command = """
        caddy start --config '\(escape(configURL.path))' --adapter caddyfile && \
        sleep 1 && \
        curl -sk --resolve \(siteHost):\(sitePort):127.0.0.1 https://\(siteHost):\(sitePort)/ >/dev/null 2>&1; \
        status=$?; \
        caddy stop --admin \(adminAddress) >/dev/null 2>&1; \
        exit $status
        """

        let result = shell.runShell(command)
        let tlsStatusAfter = LocalhostTLSService().status()
        let output = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let succeeded = tlsStatusAfter.rootCertificatePresent
        let message: String
        if succeeded {
            message = "Local Caddy CA root generated automatically"
        } else {
            message = result.isSuccess
                ? "CA generation command finished but root certificate still missing"
                : "Automatic local CA generation failed"
        }

        return SetupOperationResult(
            kind: .generateLocalCA,
            succeeded: succeeded,
            message: message,
            output: output,
            performedAt: Date()
        )
    }

    private func escape(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }
}
