import Foundation

enum DashboardWarningsBuilder {
    static func build(
        caddyInstall: CaddyInstallStatus,
        tlsStatus: TLSStatus,
        runtimeTargets: [RuntimeTarget],
        autoSetupReport: AutoSetupReport,
        runtimeCommandIssues: [ShellCommandIssue]
    ) -> [String] {
        var warnings: [String] = []
        if !caddyInstall.isInstalled {
            warnings.append("Caddy is not installed. The app can still prepare configuration, but cannot apply it yet.")
        }
        if !tlsStatus.rootCertificatePresent {
            warnings.append("Caddy local CA root certificate not found yet. AutoTLS for localhost subdomains will need a trust step.")
        } else if tlsStatus.systemKeychainTrustStatus == .notTrusted {
            warnings.append("Caddy local CA root certificate exists, but is not trusted in the macOS System Keychain yet.")
        }
        if runtimeTargets.isEmpty {
            warnings.append("No Multipass or Podman targets discovered.")
        }
        for issue in runtimeCommandIssues {
            let retryText: String
            if let nextRetryAt = issue.nextRetryAt {
                let seconds = Int(max(nextRetryAt.timeIntervalSinceNow.rounded(.up), 1))
                retryText = " Next retry in \(seconds)s."
            } else {
                retryText = ""
            }
            warnings.append("No contact to \(issue.label). \(issue.message)\(retryText)")
        }
        for operation in autoSetupReport.operations where !operation.succeeded {
            warnings.append("Auto setup failed: \(operation.message)")
        }
        return warnings
    }
}
