import Foundation

struct LocalhostTLSService {
    private let shell = ShellCommandRunner()
    private let privilegedRunner = PrivilegedCommandRunner()

    func status() -> TLSStatus {
        let rootPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Caddy/pki/authorities/local/root.crt")
            .path
        let present = FileManager.default.fileExists(atPath: rootPath)
        let trustCheck = verifySystemKeychainTrust(rootCertificatePath: rootPath, rootCertificatePresent: present)

        return TLSStatus(
            localCARootPath: rootPath,
            rootCertificatePresent: present,
            systemKeychainTrustStatus: trustCheck.status,
            systemKeychainTrustDetails: trustCheck.details,
            caddyTrustCommand: "sudo caddy trust",
            installHint: "Use 'caddy trust' for system keychain install, or import root.crt manually into macOS Keychain (System)."
        )
    }

    func trustLocalCAWithSystemPrompt() -> SetupOperationResult {
        let caddyPath = ShellCommandRunner().runShell("command -v caddy").stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !caddyPath.isEmpty else {
            return SetupOperationResult(
                kind: .trustLocalCA,
                succeeded: false,
                message: "Caddy is not installed; cannot run trust step",
                output: "",
                performedAt: Date()
            )
        }

        let escapedCaddyPath = caddyPath.replacingOccurrences(of: "'", with: "'\\''")
        let privilegedCommand = "'\(escapedCaddyPath)' trust"

        let result = privilegedRunner.runWithAdministratorPrivileges(
            privilegedCommand,
            prompt: "CaddyApp needs permission to trust Caddy's local root certificate in the macOS system keychain."
        )

        let output = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let success = result.isSuccess || isNonFatalJavaTrustFailure(output: output)
        let message: String
        if result.isSuccess {
            message = "Local Caddy root certificate trusted via macOS authorization dialog"
        } else if isNonFatalJavaTrustFailure(output: output) {
            message = "Local Caddy root certificate trusted (Java trust skipped: JAVA_HOME not set)"
        } else {
            message = "Trust step failed or was cancelled"
        }

        return SetupOperationResult(
            kind: .trustLocalCA,
            succeeded: success,
            message: message,
            output: output,
            performedAt: Date()
        )
    }

    private func isNonFatalJavaTrustFailure(output: String) -> Bool {
        let lowered = output.lowercased()

        let mentionsJavaHome = lowered.contains("define java_home environment variable to use the java trust")
            || lowered.contains("java_home")
        let performedTrustInstall = lowered.contains("installing root certificate")
        let onlyKnownCaddyWrapperFailure = lowered.contains("failed to execute sudo: exit status 1")
            || lowered.contains("applescript error 1")

        return mentionsJavaHome && performedTrustInstall && onlyKnownCaddyWrapperFailure
    }

    private func verifySystemKeychainTrust(
        rootCertificatePath: String,
        rootCertificatePresent: Bool
    ) -> (status: CertificateTrustStatus, details: String) {
        guard rootCertificatePresent else {
            return (
                .notChecked,
                "Root certificate file is missing, so System Keychain trust cannot be verified yet."
            )
        }

        let fingerprintResult = shell.run(
            "/usr/bin/openssl",
            arguments: ["x509", "-in", rootCertificatePath, "-noout", "-fingerprint", "-sha256"]
        )
        guard fingerprintResult.isSuccess else {
            let details = fingerprintResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                .unknown,
                details.isEmpty
                    ? "Failed to read root certificate fingerprint with openssl."
                    : "Failed to read root certificate fingerprint with openssl: \(details)"
            )
        }

        guard let fingerprint = parseSHA256Fingerprint(fingerprintResult.stdout) else {
            return (.unknown, "Could not parse SHA-256 fingerprint of the local Caddy root certificate.")
        }

        let keychainResult = shell.run(
            "/usr/bin/security",
            arguments: ["find-certificate", "-a", "-Z", "/Library/Keychains/System.keychain"]
        )
        guard keychainResult.isSuccess else {
            let details = [keychainResult.stdout, keychainResult.stderr]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            return (
                .unknown,
                details.isEmpty
                    ? "Failed to inspect System Keychain certificates."
                    : "Failed to inspect System Keychain certificates: \(details)"
            )
        }

        let systemKeychainDump = (keychainResult.stdout + "\n" + keychainResult.stderr).uppercased()
        guard systemKeychainDump.contains(fingerprint) else {
            return (
                .notTrusted,
                "Local Caddy root certificate file exists, but its fingerprint was not found in System Keychain."
            )
        }

        let verifyResult = shell.run(
            "/usr/bin/security",
            arguments: [
                "verify-cert",
                "-p", "basic",
                "-l",
                "-L",
                "-N",
                "-c", rootCertificatePath,
                "-k", "/Library/Keychains/System.keychain"
            ]
        )
        if verifyResult.isSuccess {
            return (
                .trusted,
                "Matching local Caddy root certificate fingerprint found in System Keychain and verification succeeded."
            )
        }

        let verifyDetails = [verifyResult.stdout, verifyResult.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return (
            .notTrusted,
            verifyDetails.isEmpty
                ? "Root certificate was found in System Keychain, but trust verification failed."
                : "Root certificate was found in System Keychain, but trust verification failed: \(verifyDetails)"
        )
    }

    private func parseSHA256Fingerprint(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue = trimmed.split(separator: "=").last else { return nil }
        let normalized = rawValue
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalized.isEmpty ? nil : normalized
    }
}
